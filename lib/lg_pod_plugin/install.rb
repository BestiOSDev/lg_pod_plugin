require 'pp'
require 'git'
require 'cgi'
require 'cocoapods'
require_relative 'request'
require_relative 'database'
require_relative 'downloader'
require 'cocoapods-core/podfile'
require_relative 'release-pod'
require_relative 'gitlab_download'
require 'cocoapods-core/podfile/target_definition'

module LgPodPlugin

  class Installer
    REQUIRED_ATTRS ||= %i[name version options target workspace].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(profile, name, requirements)
      unless name
        raise StandardError, 'A dependency requires a name.'
      end
      self.name = LUtils.pod_real_name(name)
      self.workspace = profile.send(:defined_in_file).dirname
      self.target = profile.send(:current_target_definition)
      unless requirements && requirements.is_a?(Hash)
        LRequest.shared.libs.delete(name)
        LgPodPlugin.log_red "pod `#{name}`, 缺少必要的 [git|commit|tag|branch] 参数"
        return
      end
      git = requirements[:git]
      tag = requirements[:tag]
      commit = requirements[:commit]
      branch = requirements[:branch]
      hash_map = Hash.new.merge!(requirements)
      if git
        if tag
          hash_map.delete(:branch)
          hash_map.delete(:commit)
        elsif commit
          hash_map.delete(:tag)
          hash_map.delete(:branch)
        elsif branch
          hash_map.delete(:tag)
          hash_map.delete(:commit)
        else
          hash_map.delete(:tag)
          hash_map.delete(:branch)
          hash_map.delete(:commit)
        end
      end
      self.options = hash_map
      LRequest.shared.setup_pod_info(self.name, self.workspace, hash_map)
      self.install_remote_pod(name, hash_map)
    end

    public
    def install_remote_pod(name, options = {})
      git = options[:git]
      if git
        if LRequest.shared.net_ping.ip && LRequest.shared.net_ping.network_ok
          LRequest.shared.downloader.pre_download_pod
        else
          LgPodPlugin.log_red "请求#{git} 超时, 下载失败!"
        end
      else
        LRequest.shared.libs.delete(name)
        LgPodPlugin.log_red "pod `#{name}`, 缺少必要的 [git|commit|tag|branch] 参数"
      end
    end

  end
end
