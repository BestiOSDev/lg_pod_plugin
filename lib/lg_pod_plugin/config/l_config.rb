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
      return nil unless uri&.hostname
      return nil unless LUtils.is_gitlab_uri(git, uri.hostname)
      user_id = LUserAuthInfo.get_user_id(uri.hostname)
      user_info = LSqliteDb.shared.query_user_info(user_id)
      if user_info != nil
        user_info = GitLabAPI.check_gitlab_access_token_valid(uri, user_info)
      else
        user_info = GitLabAPI.get_gitlab_access_token(uri, user_id)
      end
      return nil unless user_info
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
