require  'zip'
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
    #fe1f9dcfe4bacfb09235449623adc9e4bf0bff94fd5829f5cc80f61502960995
    # 下载 zip 格式文件
    def self.download_zip_file(download_url, token, file_name)
      cmds = ['curl']
      cmds << "-s"
      cmds << "--header \"Authorization: Bearer #{token}\"" if token
      cmds << "-o #{file_name}"
      cmds << "--connect-timeout 15"
      cmds << "--retry 3"
      cmds << download_url
      cmds_to_s = cmds.join(" ")
      system(cmds_to_s)
    end

    # 是否能够使用 gitlab 下载 zip 文件
    def self.is_use_gitlab_archive_file(git)
      return false if git.include?("https://github.com") || git.include?("https://gitee.com")
      config = LRequest.shared.config
      return false unless config
      return false unless config.private_token
      if git.include?(config.group_name)
        return true
      elsif config.projects.empty?
        return false
      else
        base_url = self.get_gitlab_base_url(git)
        project_name = base_url.split("/").last if base_url
        project = config.projects[project_name]
        if project && project.is_a?(Hash) && project["id"]
          return true
        else
          config.projects.each do |key, val|
            next unless val.is_a?(Hash)
            if val["ssh_url_to_repo"] == git || val["http_url_to_repo"] == git
              return true
            end
          end
          return false
        end
      end
    end

    # 截取 url
    def self.get_gitlab_base_url(git)
      if git.include?(".git")
        base_url = git[0...git.length - 4]
      else
        base_url = git
      end
      return base_url
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
      projects = LRequest.shared.config.projects if LRequest.shared.config.projects.is_a?(Hash)
      projects.each do |key, val|
        next unless val.is_a?(Hash)
        ssh_url_to_repo = val["ssh_url_to_repo"]
        if ssh_url_to_repo && ssh_url_to_repo.include?(base_url)
          new_base_url = val["http_url_to_repo"]
          break
        end
      end
      return nil unless new_base_url
      new_base_url = self.get_gitlab_base_url(new_base_url)
      new_project_name = new_base_url.split("/").last
      return nil unless new_project_name
      if branch
        return new_base_url + "/-/archive/" + branch + "/#{new_project_name}-#{branch}.zip"
      elsif tag
        return new_base_url + "/-/archive/" + tag + "/#{new_project_name}-#{tag}.zip"
      elsif commit
        return new_base_url + "/-/archive/" + commit + "/#{new_project_name}-#{commit}.zip"
      else
        return nil
      end
    end
  end
  end
