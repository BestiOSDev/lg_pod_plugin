require 'zip'
require_relative 'log'
require_relative 'l_config'
module LgPodPlugin
  class LUtils
    def self.unzip_file (zip_file, dest_dir)
      begin
        LgPodPlugin.log_green "正在解压`.zip`文件"
        Zip::File.open(zip_file) do |file|
          file.each do |f|
            file_path = File.join(dest_dir, f.name)
            FileUtils.mkdir_p(File.dirname(file_path))
            # next if file_path.include?("LICENSE")
            next if file_path.include?("Example")
            next if file_path.include?(".gitignore")
            next if file_path.include?("node_modules")
            next if file_path.include?("package.json")
            next if file_path.include?(".swiftlint.yml")
            next if file_path.include?("_Pods.xcodeproj")
            next if file_path.include?("package-lock.json")
            next if file_path.include?("README.md")
            next if file_path.include?("commitlint.config.js")
            file.extract(f, file_path)
          end
        end
        return true
      rescue => err
        LgPodPlugin.log_red "解压zip失败, error => #{err}"
        return false
      end

    end

    def self.aes_decrypt(key, data)
      de_cipher = OpenSSL::Cipher::Cipher.new("AES-128-CBC")
      de_cipher.decrypt
      de_cipher.key = [key].pack('H*')
      # de_cipher.iv = [iv].pack('H*');
      puts de_cipher.update([data].pack('H*')) << de_cipher.final
    end

    # 下载 zip 格式文件
    def self.download_zip_file(download_url, token, file_name)
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
        project = GitLab.request_project_info(config.host, project_name, config.access_token)
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
      new_base_url = nil
      project = LRequest.shared.config.project
      if project && project.web_url && project.web_url.include?("http")
        self.get_gitlab_download_url(project.web_url, branch, tag, commit, project_name)
      else

      end

    end
  end
end
