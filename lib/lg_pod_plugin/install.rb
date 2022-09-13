require 'pp'
require 'git'
require 'cgi'
require 'sqlite3'
require 'cocoapods'
require_relative 'database'
require_relative 'download'
require_relative 'git_util'
require_relative 'pod_spec.rb'

module LgPodPlugin
  class Installer
    attr_accessor :profile
    attr_accessor :target
    attr_accessor :downloader
    attr_accessor :git_util
    def initialize(defined_in_file = nil, profile, &block)
      @defined_in_file = defined_in_file
      self.profile = profile
      self.git_util = GitUtil.new
      self.downloader = Downloader.new
      self.target = profile.send(:current_target_definition)
      if block
        instance_eval(&block)
      end
    end

    # @param [Object] name
    # @param [Hash] options
    # @return [Object] nil
    def pod(name, options = {})
      unless name
        raise StandardError, 'A dependency requires a name.'
      end
      if options[0].is_a?(String)
        version = options[0].to_s
        @target.store_pod(name, version)
        return
      end

      path = options[:path]
      tag = options[:tag]
      commit = options[:commit]
      url = options[:git]
      branch = options[:branch]
      depth = options[:depth] ||= true
      real_path = Pathname(path).expand_path
      # real_path = File.expand_path(path, profile_path)
      # 找到本地组件库 执行 git pull
      if real_path && File.directory?(real_path)
        self.install_local_pod(name, options)
        return
      end

      # 根据tag, commit下载文件
      hash_map = options
      hash_map.delete(:path)
      if tag || commit
        hash_map.delete(:branch)
        hash_map.delete(:depth)
        @target.store_pod(name, hash_map)
        return
      end

      # 根据 branch 下载代码
      if url && branch && depth
        hash_map.delete(:tag)
        hash_map.delete(:commit)
        hash_map.delete(:depth)
        self.downloader.download_init(name, options)
        self.downloader.pre_download_pod(self.git_util)
        @target.store_pod(name, hash_map)
      end

    end

    def install_form_specs(spec_path = nil)
      spec_path ||= './Specs'
      path = File.expand_path(spec_path, Dir.pwd)
      file_objects = Dir.glob(File.expand_path("*.rb",path)).map do |file_path|
        #读取 xxx.rb文件
        Spec.form_file(file_path)
      end
      # 便利出每一个pod对安装信息
      file_objects.each do |file|
        if file.install
          options = file.pod_requirements
          self.pod(file.name, options)
        end
      end

    end

    private
    def install_local_pod(name, options = {})
      hash_map = options
      path = options[:path]
      branch = options[:branch]
      unless Dir.exist?(path)
        puts "no such file or directory at path => `#{path}`"
        return
      end
      local_path = Pathname(path)
      unless local_path.glob("*.git").empty?
        puts "path => `#{local_path}` 找不到.git目录"
      end
      self.git_util.git_init(name, :branch => branch, :path => local_path)
      self.git_util.git_local_pod_check
      hash_map.delete(:tag)
      hash_map.delete(:git)
      hash_map.delete(:depth)
      hash_map.delete(:commit)
      hash_map.delete(:branch)
      # 安装本地私有组件库
      @target.store_pod(name, hash_map)
    end

  end
end
