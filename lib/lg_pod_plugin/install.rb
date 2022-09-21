require 'pp'
require 'git'
require 'cgi'
require 'cocoapods'
require_relative 'request'
require_relative 'database'
require_relative 'git_util'
require_relative 'downloader.rb'

module LgPodPlugin

  class Installer

    REQUIRED_ATTRS ||= %i[name version options target real_name workspace].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(profile, name, *requirements)
      if name.include?("/")
        self.name = name.split("/").first
      else
        self.name = name
      end
      self.real_name = name
      self.workspace = profile.send(:defined_in_file).dirname
      self.target = profile.send(:current_target_definition)

      unless requirements && !requirements.empty?
        LRequest.shared.setup_pod_info(self.name, self.workspace, nil)
        self.lg_pod(self.real_name, requirements)
        return
      end

      first = requirements[0].first
      if "#{first.class}" == "String"
        self.version = first
      elsif "#{first.class}" == "Hash"
        self.options = first
      end
      hash_map = nil
      last = requirements[0].last
      if "#{last.class}" == "Hash"
        hash_map = last
      end
      git = hash_map[:git]
      if hash_map && git
        tag = hash_map[:tag]
        branch = hash_map[:branch]
        commit = hash_map[:commit]
        if tag
          hash_map.delete(:branch)
          hash_map.delete(:commit)
        elsif commit
          hash_map.delete(:tag)
          hash_map.delete(:branch)
        elsif branch
          hash_map.delete(:tag)
          hash_map.delete(:commit)
        end
      end
      self.options = hash_map
      LRequest.shared.setup_pod_info(self.name, self.workspace, hash_map)
      self.lg_pod(name, requirements)
    end

    public
    def lg_pod(name, *requirements)
      unless name
        raise StandardError, 'A dependency requires a name.'
      end

      # 根据pod name安装, pod 'AFNetworking'
      unless requirements
        self.target.store_pod(self.real_name)
        return
      end
      # 根据name, version 安装, pod 'AFNetworking', "1.0.1"
      if self.version && !self.options
        self.target.store_pod(self.real_name, self.version)
        return
      end
      # 根据name, version 安装, pod 'AFNetworking', "1.0.1", :configurations => ["Debug"]
      if self.version && self.options
        hash_map = self.options
        # hash_map.delete(:cache)
        self.target.store_pod(self.real_name, self.version, hash_map)
        return
      end

      hash_map = self.options
      unless hash_map.is_a?(Hash)
        self.target.store_pod(self.real_name)
        return
      end

      path = hash_map[:path]
      if path
        self.install_local_pod(name, path, options)
      else
        hash_map.delete(:path)
        self.install_remote_pod(name, hash_map)
      end

    end

    public
    def install_remote_pod(name, options = {})
      git = options[:git]
      if git
        LRequest.shared.downloader.pre_download_pod
        self.target.store_pod(self.real_name, options)
      else
        LgPodPlugin.log_red "pod `#{name}` 的参数 path, git , tag , commit不正确"
      end
    end

    public
    #安装本地pod
    def install_local_pod(name, relative_path, options = {})
      hash_map = options
      absolute_path = Pathname.new(relative_path).expand_path(self.workspace)

      unless absolute_path.exist?
        hash_map.delete(:path)
        self.install_remote_pod(name, hash_map)
        return
      end

      if Dir.glob(File.expand_path(".git", absolute_path)).empty?
        hash_map.delete(:path)
        self.install_remote_pod(name, hash_map)
        return
      end

      if Dir.glob(File.expand_path("#{name}.podspec", absolute_path)).empty?
        hash_map.delete(:path)
        self.install_remote_pod(name, hash_map)
        return
      end
      # LRequest.shared.git_util.git_local_pod_check(absolute_path)
      hash_map.delete(:tag)
      hash_map.delete(:git)
      # hash_map.delete(:cache)
      hash_map.delete(:commit)
      hash_map.delete(:branch)
      # 安装本地私有组件库
      self.target.store_pod(self.real_name, hash_map)
    end

  end
end
