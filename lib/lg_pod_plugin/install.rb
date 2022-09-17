require 'pp'
require 'git'
require 'cgi'
require 'sqlite3'
require 'cocoapods'
require_relative 'request'
require_relative 'database'
require_relative 'download'
require_relative 'git_util'

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

      hash_map = requirements[0].last
      if "#{hash_map.class}" == "Hash"
        self.options = hash_map
      end
      LRequest.shared.setup_pod_info(self.name, self.workspace, self.options)
      self.lg_pod(name, requirements)
    end

    public
    def lg_pod(name, *requirements)
      unless name
        raise StandardError, 'A dependency requires a name.'
      end

      # 根据pod name安装, pod 'AFNetworking'
      if !requirements
        self.target.store_pod(self.real_name)
        return
      end
      # 根据name, verison 安装, pod 'AFNetworking', "1.0.1"
      if self.version && !self.options
        self.target.store_pod(self.real_name, self.version)
        return
      end
      # 根据name, verison 安装, pod 'AFNetworking', "1.0.1", :configurations => ["Debug"]
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
      if path && Dir.exist?(path)
        self.install_local_pod(name, path, options)
        return
      end
      hash_map.delete(:path)
      git = hash_map[:git]
      # 根据git_url 下载远程仓库
      if git
        LRequest.shared.downloader.pre_download_pod
        # hash_map.delete(:cache)
        self.target.store_pod(self.real_name, hash_map)
      else
        #hash_map.delete(:cache)
        self.target.store_pod(self.real_name, hash_map)
      end

    end

    public
    #安装本地pod
    def install_local_pod(name, relative_path, options = {})
      hash_map = options
      branch = options[:branch]
      absolute_path = Pathname.new(relative_path).expand_path(self.workspace)
      unless absolute_path.exist?
        LgPodPlugin.log_red("pod `#{name}` at path => #{relative_path} 找不到")
        return
      end
      unless Dir.glob(File.expand_path(".git", absolute_path)).count > 0
        LgPodPlugin.log_red("pod `#{name}` at path => #{absolute_path} 找不到.git目录")
        return
      end
      unless Dir.glob(File.expand_path("#{name}.podspec", absolute_path)).count > 0
        LgPodPlugin.log_red("pod `#{name}` at path => #{absolute_path} 找不到#{name}.podspec文件")
        return
      end

      LRequest.shared.git_util.git_local_pod_check(absolute_path)
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
