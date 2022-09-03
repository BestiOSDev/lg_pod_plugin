require 'pp'
require 'git'
require 'cocoapods'
require_relative 'git_clone.rb'

module LgPodPlugin
  class Installer

    # 预下载处理
    def self.pre_download(name, target, options = {})
      git_url = options[:git]
      commit = options[:commit]
      branch = options[:branch]
      GitHelper.git_pre_downloading(name, git_url, branch, commit)
    end

    # @param [Object] name
    # @param [Object] target
    # @param [Hash] options
    # @return [Object] nil
    def self.pod(name, target, options = {})
      path = options[:path]
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
      elsif !path.nil?
        hash_map = options
        hash_map.delete(:path)
        if depth == true && !branch.nil? && !git_url.nil?
          pre_download name, target, options
          hash_map.delete(:depth)
          target.store_pod(name, hash_map)
        else
          hash_map.delete(:depth)
          target.store_pod(name, hash_map)
        end
      else
        hash_map = options
        if depth == true && !branch.nil? && !git_url.nil?
          pre_download name, target, options
          hash_map.delete(:depth)
          target.store_pod(name, hash_map)
        else
          hash_map.delete(:depth)
          target.store_pod(name, hash_map)
        end
      end

    end
  end
end
