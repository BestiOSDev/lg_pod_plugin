require 'pp'
require 'git'
require 'cocoapods'
require_relative 'pod_spec.rb'
require_relative 'git_clone.rb'

module LgPodPlugin
  class Installer

    # 预下载处理
    def self.pre_download(name, options = {})
      GitHelper.git_pre_downloading(name, options)
    end

    # @param [Object] name
    # @param [Object] target
    # @param [Hash] options
    # @return [Object] nil
    def self.pod(name, target, options = {})
      path = options[:path]
      tag = options[:tag]
      commit = options[:commit]
      git_url = options[:git]
      branch = options[:branch]
      depth = options[:depth]
      if !path.nil? && File.directory?(path)
        # 找到本地组件库 执行 git pull
        Dir.chdir(path) do
          GitHelper.install_local_pod(branch)
        end
        hash_map = options
        hash_map.delete(:tag)
        hash_map.delete(:git)
        hash_map.delete(:branch)
        # 安装本地私有组件库
        target.store_pod(name, hash_map)
      else
        hash_map = options
        hash_map.delete(:path)
        if (depth && !git_url.nil?) && (branch || commit || tag)
          pre_download name, options
          hash_map.delete(:depth)
          target.store_pod(name, hash_map)
        else
          hash_map.delete(:depth)
          target.store_pod(name, hash_map)
        end
      end

    end

    def self.install(target, spec_path = nil)
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
          self.pod(file.name, target, options)
        end
      end

    end

  end
end
