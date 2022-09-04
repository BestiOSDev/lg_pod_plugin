require 'pp'
require 'git'
require 'cocoapods'
require_relative 'pod_spec.rb'
require_relative 'git_clone.rb'

module LgPodPlugin
  class Installer
    def initialize(defined_in_file = nil, target, &block)
      @defined_in_file = defined_in_file
      @target = target
      if block
        instance_eval(&block)
      end
    end
    # 预下载处理
    def pre_download(name, options = {})
      GitHelper.git_pre_downloading(name, options)
    end

    # @param [Object] name
    # @param [Hash] options
    # @return [Object] nil
    def pod(name, options = {})
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
      depth = options[:depth]
      hash_map = options
      # 找到本地组件库 执行 git pull
      if path && File.directory?(path)
        Dir.chdir(path) do
          GitHelper.install_local_pod(branch)
        end
        hash_map.delete(:tag)
        hash_map.delete(:git)
        hash_map.delete(:commit)
        hash_map.delete(:branch)
        # 安装本地私有组件库
        @target.store_pod(name, hash_map)
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
      if depth && url && branch
        hash_map.delete(:tag)
        hash_map.delete(:commit)
        hash_map.delete(:depth)
        pre_download name, options
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

  end
end
