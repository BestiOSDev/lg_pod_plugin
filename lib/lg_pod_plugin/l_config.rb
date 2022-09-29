require 'json'
require 'uri'
require 'resolv'
require "ipaddr"
require 'io/console'
require_relative 'gitlab'
require_relative 'database'

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
      begin
        uri = URI(git)
      rescue
        if git.include?("git@") && git.include?(":")
          uri = URI("http://" + git[4...git.length].split(":").first)
        else
          uri = URL("https://www.baidu.com")
        end
      end
      begin
        is_ip = true if ip_address = Resolv.getaddress(uri.host)
      rescue
        ip_address = %x(ping #{uri.host} -c 1).split("\n").first
        if ip_address && ip_address.include?("(") && ip_address.include?("):")
          ip_address = ip_address.split("(").last.split(")").first
          is_ip = true if IPAddr.new ip_address
        else
          ip_address = ""
          is_ip = false
        end
      end
      unless is_ip
        LgPodPlugin.log_yellow "找不到 #{git}的IP地址"
        return nil
      end
      if uri.scheme.include?("ssh") || git.include?("git@gitlab") || git.include?("git@")
        host = "http://" + ip_address
      else
        host = "#{uri.scheme}://" + ip_address
      end
      user_id = LUserAuthInfo.get_user_id(host)
      user_info = LSqliteDb.shared.query_user_info(user_id)
      unless user_info
        LgPodPlugin.log_yellow "请输入 `#{uri}` 的用户名"
        username = STDIN.gets.chomp
        LgPodPlugin.log_yellow "请输入 `#{uri}` 的密码"
        password = STDIN.noecho(&:gets).chomp
        GitLab.request_gitlab_access_token(host, username, password)
        return nil unless user_info = LSqliteDb.shared.query_user_info(user_id)
      end

      time = Time.now.to_i
      # 判断 token 是否失效
      if user_info.expires_in <= time
        new_user_info = GitLab.refresh_gitlab_access_token(host, user_info.refresh_token)
        return nil unless new_user_info
        user_info.expires_in = new_user_info.expires_in
        user_info.access_token = new_user_info.access_token
        user_info.access_token = new_user_info.access_token
        LSqliteDb.shared.insert_user_info(user_info)
        config = LConfig.new
        config.host = host
        config.access_token = user_info.access_token
        config.refresh_token = user_info.refresh_token
        config.base_url = LUtils.get_gitlab_base_url(git)
        config.project_name = LUtils.get_git_project_name(git)
        config.project = LSqliteDb.shared.query_project_info(config.project_name)
        return config
      else
        config = LConfig.new
        config.host = host
        config.access_token = user_info.access_token
        config.refresh_token = user_info.refresh_token
        config.base_url = LUtils.get_gitlab_base_url(git)
        config.project_name = LUtils.get_git_project_name(git)
        config.project = LSqliteDb.shared.query_project_info(config.project_name)
        return config
      end

    end

  end
end