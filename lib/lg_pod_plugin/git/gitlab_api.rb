require 'json'
require 'net/http'
module LgPodPlugin

  class GitLabAPI

    def self.get_gitlab_access_token_by_input(uri, user_id, username = nil, password = nil)
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
        res = Net::HTTP.start(uri.hostname, uri.port) do |http|
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
        json = JSON.parse(res.body) if res.body
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
    def self.request_project_info(host,project_name, access_token, git = nil )
      begin
        hash_map = Hash.new
        hash_map["search"] = project_name
        hash_map["access_token"] = access_token
        uri = URI("#{host}/api/v4/projects")
        uri.query = URI.encode_www_form(hash_map)
        res = Net::HTTP.get_response(uri)
        array = JSON.parse(res.body) if res.body
        return nil unless array.is_a?(Array)
        array.each do |json|
          path = json["path"] ||= ""
          path_with_namespace = json["path_with_namespace"] ||= ""
          name_with_namespace = (json["name_with_namespace"] ||= "").gsub(/[ ]/, '')
          next unless (name == project_name || path == project_name)
          next unless git.include?(name_with_namespace) || git.include?(path_with_namespace)
          id = json["id"]
          name = json["name"] ||= ""
          web_url = json["web_url"]
          description = json["description"]
          ssh_url_to_repo = json["ssh_url_to_repo"]
          http_url_to_repo = json["http_url_to_repo"]
          project = ProjectModel.new(id, name, description, path, ssh_url_to_repo, http_url_to_repo, web_url, name_with_namespace, path_with_namespace)
          LSqliteDb.shared.insert_project(project)
          return project
        end
      rescue
        return nil
      end
    end

  end


end
