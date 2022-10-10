require 'resolv'
require "ipaddr"
require 'archive/zip'
require_relative 'log'
require_relative 'l_config'

module LgPodPlugin
  class LUtils

    #判断对象是不是 String
    def self.is_string(obj)
      if "#{obj.class}" == "String"
        return true 
      else 
        return false 
      end
    end

    # 解压文件
    def self.unzip_file (zip_file, dest_dir)
      begin
        Archive::Zip.extract(
          zip_file,
          dest_dir,
          :symlinks => true
        )
        return true
      rescue => err
        return false
      end

    end

    # 下载 zip 格式文件
    def self.download_gitlab_zip_file(download_url, token, file_name)
      cmds = ['curl']
      cmds << "--header \"Authorization: Bearer #{token}\"" if token
      # cmds << "--progress-bar"
      cmds << "-o #{file_name}"
      cmds << "--connect-timeout 15"
      cmds << "--retry 3"
      cmds << download_url
      cmds_to_s = cmds.join(" ")
      system(cmds_to_s)
    end

    # gitlab 下载压缩文件
    def self.download_github_zip_file(download_url, file_name)
      cmds = ['curl']
      cmds << "-o #{file_name}"
      cmds << "--connect-timeout 15"
      cmds << "--retry 3"
      cmds << download_url
      cmds_to_s = cmds.join(" ")
      system(cmds_to_s)
    end

    def self.git_to_uri(git)
      begin
        uri = URI(git)
      rescue
        if git.include?("git@") && git.include?(":")
          uri = URI("http://" + git[4...git.length].split(":").first)
        else
          return nil
        end
      end
    end

    # 将一个host 转成ip 地址
    # def self.git_server_ip_address(git)
    #   return [nil, false ] unless uri = self.git_to_uri(git)
    #   result = %x(ping #{uri.host} -t 3)
    #   if result.include?("timeout")
    #     return [nil, false]
    #   end
    #   if result && result.include?("(") && result.include?("):")
    #     ip_address = result.split("(").last.split(")").first
    #     begin
    #       if IPAddr.new ip_address
    #         return [ip_address, true]
    #       else
    #         return [ip_address, false]
    #       end
    #     rescue
    #       return [nil, false]
    #     end
    #   else
    #     return [nil, false]
    #   end
    # end

    #截取git-url 拿到项目绝对名称 比如 l-base-ios
    def self.get_git_project_name(git)
      self.get_gitlab_base_url(git).split("/").last
    end

    # 是否能够使用 gitlab 下载 zip 文件
    def self.is_use_gitlab_archive_file(git)
      return false if git.include?("https://github.com") || git.include?("https://gitee.com")
      config = LRequest.shared.config
      return false if (!config || !config.access_token)
      return true if project = config.project
      project_name = self.get_git_project_name(git)
      LRequest.shared.config.project = GitLabAPI.request_project_info(config.host, project_name, config.access_token, git)
      return true if LRequest.shared.config.project
    end

    # 截取 url
    def self.get_gitlab_base_url(git)
      if git.include?(".git")
        base_url = git.split(".git").first
      else
        base_url = git
      end
    end

    # 根据参数生成下载 url
    def self.get_gitlab_download_url(base_url, branch, tag, commit, project_name)
      if base_url.include?("http:") || base_url.include?("https:")
        if branch
          return base_url + "/-/archive/" + branch + "/#{project_name}-#{branch}.zip"
        elsif tag
          return base_url + "/-/archive/" + tag + "/#{project_name}-#{tag}.zip"
        elsif commit
          return base_url + "/-/archive/" + commit + "/#{project_name}-#{commit}.zip"
        else
          return nil
        end
      end
      return nil unless base_url.include?("ssh://git@gitlab") || base_url.include?("git@")
      project = LRequest.shared.config.project
      if project && project.web_url && project.web_url.include?("http")
        self.get_gitlab_download_url(project.web_url, branch, tag, commit, project_name)
      else
        return nil
      end
    end

    def self.url_encode(url)
      url.to_s.b.gsub(/[^a-zA-Z0-9_\-.~]/n) { |m| sprintf('%%%02X', m.unpack1('C')) }
    end

  end
end
