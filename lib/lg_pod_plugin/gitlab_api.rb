require 'json'
require 'net/http'
require 'gitlab'
require 'expect'
require_relative 'database'
require_relative 'file_path'

module LgPodPlugin

  class GitLabAPI

    public
    # 获取 GitLab access_token
    def self.request_gitlab_access_token(host, username, password)
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
          LgPodPlugin.log_red "获取 `access_token` 失败, 请检查用户名和密码是否有误!"
          return
        end
        if (json["error"] != nil)
          raise json["error_description"]
        end
        access_token = json["access_token"]
        refresh_token = json["refresh_token"]
        expires_in = json["expires_in"] ||= 7200
        created_at = json["created_at"] ||= Time.now.to_i
        user_id = LUserAuthInfo.get_user_id(host)
        user_model = LUserAuthInfo.new(user_id, username, password, host, access_token, refresh_token, (created_at + expires_in))
        LSqliteDb.shared.insert_user_info(user_model)
        GitLabAPI.get_user_projects(access_token, host, 1)
        LgPodPlugin.log_green "请求成功: `access_token` => #{access_token}, expires_in => #{expires_in}"
      rescue => exception
        LgPodPlugin.log_red "获取 `access_token` 失败, error => #{exception.to_s}"
      end
    end

    #获取用户所有项目
    def self.get_user_projects(access_token, host, page)
      # Gitlab.endpoint = "#{host}/api/v4"
      # Gitlab.private_token = access_token
      ENV['GITLAB_API_HTTPARTY_OPTIONS'] = '{read_timeout: 60}'
      g = Gitlab.client(
        endpoint: "#{host}/api/v4",
        private_token: access_token,
        httparty: {
          headers: { 'Cookie' => 'gitlab_canary=true' }
        }
      )
      projects = g.projects(per_page: 100, page: page)
      projects.each do |hash|
        json = hash.send(:data)
        id = json["id"]
        name = json["name"]
        path = json["path"]
        web_url = json["web_url"]
        description = json["description"]
        ssh_url_to_repo = json["ssh_url_to_repo"]
        http_url_to_repo = json["http_url_to_repo"]
        project = ProjectModel.new(id, name, description, path, ssh_url_to_repo, http_url_to_repo, web_url)
        LSqliteDb.shared.insert_project(project)
      end
      return unless projects.has_next_page?
      self.get_user_projects(access_token, host,(page + 1))
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
        unless json.is_a?(Hash)
          return nil
        end
        error = json["error"]
        if error != nil
          error_description = json["error_description"]
          raise error_description
        end
        access_token = json["access_token"]
        refresh_token = json["refresh_token"]
        expires_in = json["expires_in"] ||= 7200
        created_at = json["created_at"] ||= Time.now.to_i
        user_model = LUserAuthInfo.new(nil, nil, nil, host, access_token, refresh_token, (created_at + expires_in))
        return user_model
      rescue => exception
        LgPodPlugin.log_yellow "刷新 `access_token` 失败, error => #{exception.to_s}"
        return nil
      end
    end

    # 通过名称搜索项目信息
    def self.request_project_info(host, project_name, access_token)
      ENV['GITLAB_API_HTTPARTY_OPTIONS'] = '{read_timeout: 60}'
      g = Gitlab.client(
        endpoint: "#{host}/api/v4",
        private_token: access_token,
        httparty: {
          headers: { 'Cookie' => 'gitlab_canary=true' }
        }
      )
      projects = g.search_projects(project_name)
      projects.each do |hash|
        json = hash.send(:data)
        path = json["path"] ||= ""
        next unless (name != project_name || path != project_name)
        id = json["id"]
        name = json["name"] ||= ""
        web_url = json["web_url"]
        description = json["description"]
        ssh_url_to_repo = json["ssh_url_to_repo"]
        http_url_to_repo = json["http_url_to_repo"]
        project = ProjectModel.new
        project.id = id
        project.path = path
        project.name = name
        project.web_url = web_url
        project.description = description
        project.ssh_url_to_repo = ssh_url_to_repo
        project.http_url_to_repo = http_url_to_repo
        LSqliteDb.shared.insert_project(project)
        return project
      end
      return nil 
    end

    # 获取一个仓库归档压缩包
    def self.repo_archive(host, token, porject_id, filename, ref, format)
      ENV['GITLAB_API_HTTPARTY_OPTIONS'] = '{read_timeout: 60}'
      g = Gitlab.client(
        endpoint: "#{host}/api/v4",
        private_token: token,
        httparty: {
          headers: { 'Cookie' => 'gitlab_canary=true' }
        }
      )
      begin
        response = g.repo_archive(porject_id, ref, "zip").to_hash
        downlaod_file_name = response[:filename]
        downlaod_file_stream = response[:data]
        pp downlaod_file_stream
      rescue => exception
        pp exception
      end

    end
  end

end