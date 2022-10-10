require 'json'
require 'uri'
require 'io/console'
require_relative 'request'
require_relative 'database'
require_relative 'gitlab_api'

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
    def self.getConfig(git)
      return nil if git.include?("github.com") || git.include?("gitee.com") || git.include?("coding.net") || git.include?("code.aliyun.com")
      network_ok = LRequest.shared.network_ok
      ip_address = LRequest.shared.ip_address
      unless ip_address
        ip_address, network_ok =  LUtils.git_server_ip_address(git)
        LRequest.shared.ip_address = ip_address
        LRequest.shared.network_ok = network_ok
      end
      return nil unless ip_address && network_ok
      if git.include?("ssh") || git.include?("git@gitlab") || git.include?("git@")
        host = "http://" + ip_address
      else
        uri = LUtils.git_to_uri(git)
        unless uri
          uri = URI("https://www.baidu.com")
        end
        host = "#{uri.scheme}://" + ip_address
      end
      user_id = LUserAuthInfo.get_user_id(host)
      user_info = LSqliteDb.shared.query_user_info(user_id)
      unless user_info
        LgPodPlugin.log_yellow "请输入 `#{uri}` 的用户名"
        username = STDIN.gets.chomp
        LgPodPlugin.log_yellow "请输入 `#{uri}` 的密码"
        password = STDIN.noecho(&:gets).chomp
        GitLabAPI.request_gitlab_access_token(host, username, password)
        return nil unless user_info = LSqliteDb.shared.query_user_info(user_id)
      end

      time = Time.now.to_i
      # 判断 token 是否失效
      if user_info.expires_in <= time
        new_user_info = GitLabAPI.refresh_gitlab_access_token(host, user_info.refresh_token)
        unless new_user_info
          username = user_info.username
          password = user_info.password
          unless username && password
            LgPodPlugin.log_yellow "请输入 `#{uri}` 的用户名"
            username = STDIN.gets.chomp
            LgPodPlugin.log_yellow "请输入 `#{uri}` 的密码"
            password = STDIN.noecho(&:gets).chomp
          end
          GitLabAPI.request_gitlab_access_token(host, username, password)
          return nil unless new_user_info = LSqliteDb.shared.query_user_info(user_id)
        end

        config = LConfig.new
        config.host = host
        config.access_token = new_user_info.access_token
        config.refresh_token = new_user_info.refresh_token
        config.base_url = LUtils.get_gitlab_base_url(git)
        config.project_name = LUtils.get_git_project_name(git)
        config.project = LSqliteDb.shared.query_project_info(config.project_name, git)
        return config
      else
        config = LConfig.new
        config.host = host
        config.access_token = user_info.access_token
        config.refresh_token = user_info.refresh_token
        config.base_url = LUtils.get_gitlab_base_url(git)
        config.project_name = LUtils.get_git_project_name(git)
        config.project = LSqliteDb.shared.query_project_info(config.project_name, git)
        return config
      end

    end

  end
end