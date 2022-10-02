require 'zip'
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
        Zip::File.open(zip_file, true) do |file|
          file.each do |f|
            file_path = File.join(dest_dir, f.name)
            FileUtils.mkdir_p(File.dirname(file_path))
            next if file_path.include?("Example")
            next if file_path.include?(".gitignore")
            next if file_path.include?("node_modules")
            next if file_path.include?("package.json")
            next if file_path.include?(".swiftlint.yml")
            next if file_path.include?("_Pods.xcodeproj")
            next if file_path.include?("package-lock.json")
            next if file_path.include?("commitlint.config.js")
            file.extract(f, file_path)
          end
        end
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

    # 将一个host 转成ip 地址
    def self.git_server_ip_address(host)
      begin
        return Resolv.getaddress(host)
      rescue
        ip_address = %x(ping #{uri.host} -c 1).split("\n").first
        if ip_address && ip_address.include?("(") && ip_address.include?("):")
          ip_address = ip_address.split("(").last.split(")").first
          begin
            return ip_address if IPAddr.new ip_address
          rescue
            return nil
          end
        else
          return nil
        end
      end
    end

    #截取git-url 拿到项目名称
    def self.get_git_project_name(git)
      self.get_gitlab_base_url(git).split("/").last
    end

    # 是否能够使用 gitlab 下载 zip 文件
    def self.is_use_gitlab_archive_file(git)
      return false if git.include?("https://github.com") || git.include?("https://gitee.com")
      config = LRequest.shared.config
      return false if (!config || !config.access_token)
      project_name = config.project_name || self.get_git_project_name(git)
      project = LSqliteDb.shared.query_project_info(project_name)
      if project
        return true
      else
        project = GitLabAPI.request_project_info(config.host, project_name, config.access_token)
        if project
          LRequest.shared.config.project = project
          return true
        else
          return false
        end
      end
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
