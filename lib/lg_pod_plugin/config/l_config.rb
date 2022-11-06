require 'json'
require 'uri'
require 'io/console'

module LgPodPlugin

  class LConfig
    attr_accessor :host
    attr_accessor :base_url
    attr_accessor :project_name
    attr_accessor :access_token
    attr_accessor :refresh_token
    attr_accessor :project

    def initialize
    end

    public
    def self.get_config(git, uri)
      return nil unless uri&.host
      return nil unless LUtils.is_gitlab_uri(git, uri.hostname)
      user_id = LUserAuthInfo.get_user_id(uri.hostname)
      user_info = LSqliteDb.shared.query_user_info(user_id)
      # 用户授权 token 不存在, 提示用户输入用户名密码
      unless user_info
        user_info = GitLabAPI.get_gitlab_access_token_input(uri, user_id, nil, nil)
        return nil unless user_info
      end
      time_now = Time.now.to_i
      # 判断 token 是否失效
      if user_info.expires_in <= time_now
        # 刷新 token 失败时, 通过已经保存的用户名密码来刷新 token
        new_user_info = GitLabAPI.refresh_gitlab_access_token uri.hostname, user_info.refresh_token
        if new_user_info.nil?
          username = user_info.username
          password = user_info.password
          user_info = GitLabAPI.get_gitlab_access_token_input(uri, user_id, username, password)
          return nil unless user_info
        else
          user_info = new_user_info
        end
      end

      config = LConfig.new
      config.host = uri.hostname
      config.access_token = user_info.access_token
      config.refresh_token = user_info.refresh_token
      config.base_url = LUtils.get_gitlab_base_url(git)
      config.project_name = LUtils.get_git_project_name(git)
      config.project = LSqliteDb.shared.query_project_info(config.project_name, git)
      unless config.project
        config.project = GitLabAPI.request_project_info(config.host, config.project_name, config.access_token, git)
      end
      return config

    end

  end
end
