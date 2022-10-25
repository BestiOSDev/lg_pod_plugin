require 'resolv'
require "ipaddr"
require 'archive/zip'

module LgPodPlugin

  class LUtils

    def self.md5(text)
      return "" unless text
      return Digest::MD5.hexdigest(text)
    end

    #判断对象是不是 String
    def self.is_a_string?(obj)
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
      rescue
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
        return URI(git)
      rescue
        if git.include?("git@") && git.include?(":")
          match = %r{(?<=git@).*?(?=:)}.match(git)
          if match.nil?
            return nil
          else
            return URI("http://" + match[0])
          end
        else
          return nil
        end
      end
    end

    # 通过 git ls-remote获取最新 commit
    def self.refs_from_ls_remote(git, branch)
      cmds = ['git']
      cmds << "ls-remote"
      cmds << git
      cmds << branch if branch
      cmds_to_s = cmds.join(" ")
      LgPodPlugin.log_blue cmds_to_s
      begin
        return %x(timeout 5 #{cmds_to_s})
      rescue
        return %x(#{cmds_to_s})
      end
    end

    # 解析git ls-remote结果
    def self.sha_from_result(output, branch_name)
      return nil if branch_name.nil?
      encoded_branch_name = branch_name.dup.force_encoding(Encoding::ASCII_8BIT)
      if branch_name == "HEAD"
        match1 = %r{([a-z0-9]*)\t#{Regexp.quote(encoded_branch_name)}}.match(output)
        if match1.nil?
          sha = ""
        else
          sha = match1[1]
        end
        refs = output.split("\n")
        return [sha, nil] unless refs.is_a?(Array)
        refs.each do |element|
          next if element.include?("HEAD") || element.include?("refs/tags")
          next unless element.include?(sha)
          find_branch = element.split("refs/heads/").last
          return [sha, find_branch]
        end
      else
        match = %r{([a-z0-9]*)\trefs\/(heads|tags)\/#{Regexp.quote(encoded_branch_name)}}.match(output)
        if !match.nil?
          sha = match[1]
          branch = match[0].split("refs/heads/").last
        else
          sha = nil
          branch = nil
        end
        return [sha, branch]
      end
    end

    #截取git-url 拿到项目绝对名称 比如 l-base-ios
    def self.get_git_project_name(git)
      base_url = self.get_gitlab_base_url(git)
      match = %r{[^/]+$}.match(base_url)
      return match[0] unless match.nil?
    end

    # 截取 url
    def self.get_gitlab_base_url(git)
      if git.include?(".git")
        math = /(.*(?=.git))/.match(git)
        return math[0] unless math.nil?
      else
        return git
      end
    end

    def self.url_encode(url)
      url.to_s.b.gsub(/[^a-zA-Z0-9_\-.~]/n) { |m| sprintf('%%%02X', m.unpack1('C')) }
    end
    
    def self.pod_real_name(name)
      math = %r{(.*(?=/))}.match(name)
      return name unless math
      return math[0]
    end

  end
end
