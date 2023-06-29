require 'json'
require 'net/http'
require_relative 'github_api'
require_relative '../utils/l_util'

module LgPodPlugin

  class GitLabAPI

    # 通过读取本地文件获取 access_token
    def self.get_gitlab_access_token(uri, user_id)
      text = LUtils.encrypt("AzfAjh-xTzyRBXmYuGBr", "AZMpxzVxzbo3sFDLRZMpxzVxzbo3sFDZ")
      db_path = LFileManager.download_director.join("database")
      db_path.mkdir unless db_path.exist?
      token_file = db_path.join("access_token.json")
      return self.get_gitlab_access_token_input(uri, user_id, nil, nil) unless token_file.exist?
      json = JSON.parse(File.read("#{token_file.to_path}"))
      encrypt_access_token = json["access_token"]
      return self.get_gitlab_access_token_input(uri, user_id, nil, nil) if encrypt_access_token.nil?
      access_token = LUtils.decrypt(encrypt_access_token, "AZMpxzVxzbo3sFDLRZMpxzVxzbo3sFDZ")
      token_vaild = GitLabAPI.request_user_emails(uri.hostname, access_token)
      if token_vaild == "invalid token"
        FileUtils.rm_rf token_file
        return self.get_gitlab_access_token_input(uri, user_id, nil, nil) if encrypt_access_token.nil?
      end
      user_id = LUserAuthInfo.get_user_id(uri.hostname)
      refresh_token = json["refresh_token"]
      expires_in = json["expires_in"] ||= 7879680
      created_at = json["created_at"] ||= Time.now.to_i
      user_model = LUserAuthInfo.new(user_id, "", "", uri.hostname, access_token, refresh_token, (created_at + expires_in))
      LSqliteDb.shared.insert_user_info(user_model)
      LgPodPlugin.log_green "请求成功: `access_token` => #{access_token}, expires_in => #{expires_in}"
      return user_model
    end

    # 通过输入用户名和密码 获取 access_token
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
    # 检查 token 是否在有效期内
    def self.check_gitlab_access_token_valid(uri, user_info)
      time_now = Time.now.to_i
      # 判断 token 是否失效
      if user_info.expires_in <= time_now
        refresh_token = user_info.refresh_token
        if refresh_token.nil? || refresh_token == "" # 使用本地令牌访问
          project_name = LUtils.get_git_project_name(uri.to_s)
          token_vaild = GitLabAPI.request_user_emails(uri.hostname, user_info.access_token)
          if token_vaild == "success"
            new_user_info = LUserAuthInfo.new(user_info.id, "", "", uri.hostname, user_info.access_token, nil, (time_now + 7879680))
            LSqliteDb.shared.insert_user_info(user_info)
            return new_user_info
          else
            token_file = LFileManager.download_director.join("database").join("access_token.json")
            FileUtils.rm_rf token_file if token_file.exist?
            return self.get_gitlab_access_token_input(uri, user_info.id, nil, nil)
          end
        else
          # 刷新 token 失败时, 通过已经保存的用户名密码来刷新 token
          new_user_info = GitLabAPI.refresh_gitlab_access_token uri.hostname, refresh_token
          if new_user_info.nil?
            username = user_info.username
            password = user_info.password
            user_info = GitLabAPI.get_gitlab_access_token_input(uri, user_info.user_id, username, password)
            return nil unless user_info
          else
            user_info = new_user_info
          end
        end
      else
        return user_info
      end
    end

    public
    # 获取 GitLab access_token
    def self.request_gitlab_access_token(host, username, password)
      user_id = LUserAuthInfo.get_user_id(host)
      begin
        uri = URI("#{host}/oauth/token")
        hash_map = { "grant_type" => "password", "username" => username, "password" => password }
        LgPodPlugin.log_green "开始请求 access_token, url => #{uri.to_s} "
        req = Net::HTTP.post_form(uri, hash_map)
        json = JSON.parse(req.body)
        error = json["error"]
        if error != nil
          if error == "invalid_grant"
            LSqliteDb.shared.delete_user_info(user_id)
          end
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
          body = JSON.parse(res.body)
          message = body["message"]
          if message == "404 Project Not Found"
            LSqliteDb.shared.delete_project_by_id(project.id)
          end
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
        commit, _ = self.use_default_refs_heads git, branch
        return [commit, branch]
      end
    end

    public
    def self.get_podspec_file_content(host, token, project_id, sha, filepath)
      begin
        hash_map = Hash.new
        hash_map["ref"] = sha
        hash_map["access_token"] = token
        uri = URI("#{host}/api/v4/projects/#{project_id}/repository/files/#{filepath}")
        uri.query = URI.encode_www_form(hash_map)
        res = Net::HTTP.get_response(uri)
        case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          json = JSON.parse(res.body)
        else
          body = JSON.parse(res.body)
          message = body["message"]
          if message == "404 Project Not Found"
            LSqliteDb.shared.delete_project_by_id(project_id)
          end
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

    # 通过名称搜索项目信息
    public
    def self.request_user_emails(host, access_token)
      begin
        hash_map = {"access_token": access_token}
        uri = URI("#{host}/api/v4/user/emails")
        uri.query = URI.encode_www_form(hash_map)
        res = Net::HTTP.get_response(uri)
        if res.body
          array = JSON.parse(res.body)
        else
          array = []
        end
        if array.is_a?(Array)
          return "success"
        elsif array.is_a?(Hash)
          return "invalid token"
        else
          return "invalid token"
        end
      rescue
        return "invalid token"
      end
    end

  end

end
