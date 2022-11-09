require 'json'
require 'net/http'
require_relative 'github_api'
require_relative '../utils/l_util'

module LgPodPlugin

  class GitLabAPI

    def self.get_gitlab_access_token_input(uri, user_id, username = nil, password = nil)
      unless username && password
        LgPodPlugin.log_yellow "请输入 `#{uri.to_s}` 的用户名"
        username = STDIN.gets.chomp
        LgPodPlugin.log_yellow "请输入 `#{uri.to_s}` 的密码"
        password = STDIN.noecho(&:gets).chomp
      end
      GitLabAPI.request_gitlab_access_token(uri.hostname, username, password)
      user_info = LSqliteDb.shared.query_user_info(user_id)
      return user_info
    end

    public

    # 获取 GitLab access_token
    def self.request_gitlab_access_token(host, username, password)
      user_id = LUserAuthInfo.get_user_id(host)
      begin
        uri = URI("#{host}/oauth/token")
        hash_map = { "grant_type" => "password", "username" => username, "password" => password }
        LgPodPlugin.log_green "开始请求 access_token, url => #{uri.to_s} "
        req = Net::HTTP::Post.new(uri)
        req.set_form_data(hash_map)
        res = Net::HTTP.start((uri.hostname ||= ""), uri.port) do |http|
          http.open_timeout = 15
          http.read_timeout = 15
          http.request(req)
        end
        case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          json = JSON.parse(res.body)
        else
          json = JSON.parse(res.body)
          raise json["error_description"]
        end
        access_token = json["access_token"]
        refresh_token = json["refresh_token"]
        expires_in = json["expires_in"] ||= 7200
        created_at = json["created_at"] ||= Time.now.to_i
        user_model = LUserAuthInfo.new(user_id, username, password, host, access_token, refresh_token, (created_at + expires_in))
        LSqliteDb.shared.insert_user_info(user_model)
        LgPodPlugin.log_green "请求成功: `access_token` => #{access_token}, expires_in => #{expires_in}"
      rescue => exception
        LSqliteDb.shared.delete_user_info(user_id)
        LgPodPlugin.log_red "获取 `access_token` 失败, error => #{exception.to_s}"
      end
    end

    # 刷新gitlab_token
    def self.refresh_gitlab_access_token(host, refresh_token)
      begin
        hash_map = Hash.new
        hash_map["scope"] = "api"
        hash_map["grant_type"] = "refresh_token"
        hash_map["refresh_token"] = refresh_token
        uri = URI("#{host}/oauth/token")
        res = Net::HTTP.post_form(uri, hash_map)
        if res.body
          json = JSON.parse(res.body)
        else
          return nil
        end
        return nil unless json.is_a?(Hash)
        error = json["error"]
        if error != nil
          error_description = json["error_description"]
          raise error_description
        end
        access_token = json["access_token"]
        refresh_token = json["refresh_token"]
        expires_in = json["expires_in"] ||= 7200
        created_at = json["created_at"] ||= Time.now.to_i
        user_id = LUserAuthInfo.get_user_id(host)
        user_model = LSqliteDb.shared.query_user_info(user_id)
        user_model.expires_in = (created_at + expires_in)
        user_model.access_token = access_token
        user_model.refresh_token = refresh_token
        LSqliteDb.shared.insert_user_info(user_model)
        return user_model
      rescue => exception
        LgPodPlugin.log_yellow "刷新 `access_token` 失败, error => #{exception.to_s}"
        return nil
      end
    end

    # 通过名称搜索项目信息
    def self.request_project_info(host, project_name, access_token, git = nil)
      begin
        hash_map = Hash.new
        hash_map["search"] = project_name
        hash_map["access_token"] = access_token
        uri = URI("#{host}/api/v4/projects")
        uri.query = URI.encode_www_form(hash_map)
        res = Net::HTTP.get_response(uri)
        if res.body
          array = JSON.parse(res.body)
        else
          array = nil
        end
        return nil unless array && array.is_a?(Array)
        array.each do |json|
          name = json["name"] ||= ""
          path = json["path"] ||= ""
          path_with_namespace = json["path_with_namespace"] ||= ""
          name_with_namespace = (json["name_with_namespace"] ||= "").gsub(/[ ]/, '')
          if git.include?(path_with_namespace)
            id = json["id"]
            web_url = json["web_url"]
            description = json["description"]
            ssh_url_to_repo = json["ssh_url_to_repo"]
            http_url_to_repo = json["http_url_to_repo"]
            project = ProjectModel.new(id, name, description, path, ssh_url_to_repo, http_url_to_repo, web_url, name_with_namespace, path_with_namespace)
            LSqliteDb.shared.insert_project(project)
            return project
          end
        end
        return nil
      rescue
        return nil
      end
    end

    #请求gitlab api 获取 branch 最新的 commit
    def self.request_gitlab_refs_heads(git, branch, uri)
      config = LConfig.get_config(git, uri)
      project = config.project
      return self.use_default_refs_heads(git, branch) unless config
      unless project
        project_name = LUtils.get_git_project_name git
        project = GitLabAPI.request_project_info(config.host, project_name, config.access_token, git)
      end
      return self.use_default_refs_heads(git, branch) unless project && project.id
      begin
        new_branch = branch ? branch : "HEAD"
        api = uri.hostname + "/api/v4/projects/" + project.id + "/repository/commits/" + new_branch
        req_uri = URI(api)
        req_uri.query = URI.encode_www_form({ "access_token": config.access_token })
        res = Net::HTTP.get_response(req_uri)
        case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          json = JSON.parse(res.body)
          return [nil, nil] unless json && json.is_a?(Hash)
          sha = json["id"]
          return [sha, nil]
        else
          return self.use_default_refs_heads git, branch
        end
      rescue => exception
        LgPodPlugin.log_red "request_gitlab_refs_heads => #{exception}"
        return self.use_default_refs_heads git, branch
      end
    end

    # 使用 git 命令获取commit信息
    def self.use_default_refs_heads(git, branch)
      result = LUtils.refs_from_ls_remote git, branch
      unless result && !result.empty?
        return [nil, nil]
      end
      refs = branch ? branch : "HEAD"
      new_commit, new_branch = LUtils.sha_from_result(result, refs)
      return [new_commit, new_branch]
    end

    # 通过github api 获取 git 最新commit
    def self.request_github_refs_heads(git, branch, uri = nil)
      return [nil, nil] unless git
      unless git.include?("https://github.com/") || git.include?("git@github.com:")
        if LgPodPlugin::LUtils.is_gitlab_uri(git, "")
          return self.request_gitlab_refs_heads(git, branch, uri)
        end
        return self.use_default_refs_heads git, branch
      end
      commit, _ = GithubAPI.request_github_refs_heads git, branch
      if commit
        return [commit, branch]
      else
        return self.use_default_refs_heads git, branch
      end
    end

    #获取项目中仓库文件和目录的列表
    # def self.get_gitlab_repository_tree(host, token, project_id, sha)
    #   begin
    #     hash_map = Hash.new
    #     hash_map["ref"] = sha
    #     hash_map["access_token"] = token
    #     hash_map["per_page"] = 50
    #     uri = URI("#{host}/api/v4/projects/#{project_id}/repository/tree")
    #     uri.query = URI.encode_www_form(hash_map)
    #     res = Net::HTTP.get_response(uri)
    #     if res.body
    #       array = JSON.parse(res.body)
    #     else
    #       array = nil
    #     end
    #     return Set.new unless array && array.is_a?(Array)
    #     files = array.collect { |dict|
    #       dict["path"]
    #     }
    #     set = Set.new.merge files
    #     return set
    #   rescue
    #     return Set.new
    #   end
    # end

    public
    def self.get_podspec_file_content(host, token, project_id, sha, filepath)
      begin
        hash_map = Hash.new
        hash_map["ref"] = sha
        hash_map["access_token"] = token
        uri = URI("#{host}/api/v4/projects/#{project_id}/repository/files/#{filepath}")
        uri.query = URI.encode_www_form(hash_map)
        res = Net::HTTP.get_response(uri)
        if res.body
          json = JSON.parse(res.body)
        else
          json = nil
        end
        return nil unless json && json.is_a?(Hash)
        content = json["content"]
        return nil unless content && LUtils.is_a_string?(content)
        encoding = json["encoding"] ||= "base64"
        if encoding == "base64"
          require 'base64'
          content = Base64.decode64(content)
          if content.respond_to?(:encoding) && content.encoding.name != 'UTF-8'
            text = content.force_encoding("gb2312").force_encoding("utf-8")
            return text
          else
            return content
          end
        else
          return nil
        end
      rescue
        return nil
      end
    end

  end

end
