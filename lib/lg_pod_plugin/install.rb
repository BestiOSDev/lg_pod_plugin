require 'pp'
require 'git'
require 'cgi'
require 'sqlite3'
require 'cocoapods'
require_relative 'database'
require_relative 'download'
require_relative 'git_util'
require_relative 'pod_spec'

module LgPodPlugin

  class Installer
    # attr_accessor :name
    # attr_accessor :version
    # attr_accessor :options
    # attr_accessor :profile
    # attr_accessor :target
    # attr_accessor :real_name
    # attr_accessor :downloader
    # attr_accessor :git_util
    REQUIRED_ATTRS ||= %i[name version options profile target real_name downloader git_util].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(profile, name, *requirements)
      if name.include?("/")
        self.name = name.split("/").first
      else
        self.name = name
      end
      self.real_name = name
      self.profile = profile
      self.git_util = GitUtil.new
      self.downloader = Downloader.new
      self.target = profile.send(:current_target_definition)

      unless requirements && !requirements.empty?
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

      self.lg_pod(name, requirements)

    end

    public
    # @param [Object] name
    # @param [Hash] options
    # @return [Object] nil
    def lg_pod(name, *requirements)
      unless name
        raise StandardError, 'A dependency requires a name.'
      end

      if !requirements
        self.target.store_pod(self.real_name)
        return
      end

      if self.version && !self.options
        self.target.store_pod(self.real_name, self.version)
        return
      end

      if self.version && self.options
        self.target.store_pod(self.real_name, self.version, self.options)
        return
      end

      hash_map = self.options
      unless hash_map.is_a?(Hash)
        self.target.store_pod(self.real_name)
        return
      end

      real_path = nil
      tag = hash_map[:tag]
      url = hash_map[:git]
      path = hash_map[:path]
      commit = hash_map[:commit]
      branch = hash_map[:branch]
      depth = hash_map[:depth] ||= true
      if path
        profile_path = self.profile.send(:defined_in_file).dirname
        real_path = Pathname.new(path).expand_path(profile_path)
      end
      # 找到本地组件库 执行 git pull
      if real_path && File.directory?(real_path)
        hash_map[:path] = real_path
        self.install_local_pod(self.name, hash_map)
        return
      end

      # 根据tag, commit下载文件
      hash_map.delete(:path)
      if tag || commit
        hash_map.delete(:branch)
        hash_map.delete(:depth)
        self.target.store_pod(self.real_name, hash_map)
        return
      end

      # 根据 branch 下载代码
      if url && branch && depth
        hash_map.delete(:tag)
        hash_map.delete(:commit)
        hash_map.delete(:depth)
        self.downloader.download_init(self.name, options)
        self.downloader.pre_download_pod(self.git_util)
        self.target.store_pod(self.real_name, hash_map)
      end

    end

    public
    def install_form_specs(spec_path = nil)
      spec_path ||= './Specs'
      path = File.expand_path(spec_path, Dir.pwd)
      file_objects = Dir.glob(File.expand_path("*.rb", path)).map do |file_path|
        #读取 xxx.rb文件
        Spec.form_file(file_path)
      end
      # 便利出每一个pod对安装信息
      file_objects.each do |file|
        if file.install
          options = file.pod_requirements
          self.lg_pod(file.name, options)
        end
      end

    end

    public
    def install_local_pod(name, options = {})
      hash_map = options
      local_path = options[:path]
      branch = options[:branch]
      unless Dir.glob(File.expand_path(".git", local_path)).count > 0
        LgPodPlugin.log_red("pod `#{name}` at path => #{local_path} 找不到.git目录")
        return
      end
      unless Dir.glob(File.expand_path("#{name}.podspec", local_path)).count > 0
        LgPodPlugin.log_red("pod `#{name}` at path => #{local_path} 找不到#{name}.podspec文件")
        return
      end

      self.git_util.git_init(name, :branch => branch, :path => local_path)
      self.git_util.git_local_pod_check(local_path)
      hash_map[:path] = local_path.to_path
      hash_map.delete(:tag)
      hash_map.delete(:git)
      hash_map.delete(:depth)
      hash_map.delete(:commit)
      hash_map.delete(:branch)
      # 安装本地私有组件库
      self.target.store_pod(self.real_name, hash_map)
    end

  end
end
