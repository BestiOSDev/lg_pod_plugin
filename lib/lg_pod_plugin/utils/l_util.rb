require 'json'
require 'resolv'
require "ipaddr"
require 'base64'
require 'fileutils'
# require_relative 'aes-crypt'

module LgPodPlugin

  class LUtils

    # def self.encrypt(message, password)
    #   encrypted_data = AESCrypt.encrypt(message, password)
    #   encrypted_data.tr("\n", "")
    # end
    #
    # def self.decrypt(message, password)
    #   AESCrypt.decrypt message, password
    # end

    def self.md5(text)
      return "" unless text
      return Digest::MD5.hexdigest(text)
    end

    def self.base64_encode(text)
      Base64.encode64(text)
    end

    def self.base64_decode(text)
      Base64.decode64(text)
    end

    #判断对象是不是 String
    def self.is_a_string?(obj)
      if "#{obj.class}" == "String"
        return true
      else
        return false
      end
    end

    # 通过 git ls-remote获取最新 commit
    public
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
    public
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
        return [nil, nil] unless sha && !sha.empty?
        match2 = %r{(#{sha})\trefs\/heads\/([a-z0-9]*)}.match(output)
        return [nil, nil] if match2.nil?
        if match2[1] == sha
          new_branch = match2[2]
          return [sha, new_branch]
        else
          return [nil, nil]
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
    public
    def self.get_git_project_name(git)
      base_url = self.get_gitlab_base_url(git)
      match = %r{[^/]+$}.match(base_url)
      return match[0] unless match.nil?
    end

    # 截取 url
    public
    def self.get_gitlab_base_url(git)
      if git.include?(".git")
        math = /(.*(?=.git))/.match(git)
        return math[0] unless math.nil?
      else
        return git
      end
    end

    public
    def self.url_encode(url)
      url.to_s.b.gsub(/[^a-zA-Z0-9_\-.~]/n) { |m| sprintf('%%%02X', m.unpack1('C')) }
    end

    public
    def self.pod_real_name(name)
      math = %r{(.*(?=/))}.match(name)
      return name unless math
      return math[0]
    end

    public
    def self.is_gitlab_uri(git, hostname)
      match1 = %r{(github.com|gitee.com|coding.net|code.aliyun.com)}.match(git)
      match2 = %r{(github.com|gitee.com|coding.net|code.aliyun.com)}.match(hostname)
      return match1.nil? && match2.nil?
    end

  end

end
