require 'git'
require_relative 'l_cache'
require_relative 'file_path'

module LgPodPlugin

  class LDownloader

    REQUIRED_ATTRS ||= %i[git real_name name commit branch tag options].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(name, options = {})
      self.name = name
      self.options = Hash.new.deep_merge(options)
      self.git = self.options[:git]
      self.tag = self.options[:tag]
      self.branch = self.options[:branch]
      self.commit = self.options[:commit]
    end

    # 预下载处理
    def pre_download_pod
      if self.branch
        LgPodPlugin.log_green "Using `#{name}` (#{branch})"
      elsif self.tag
        LgPodPlugin.log_green "Using `#{name}` (#{self.tag})"
      elsif self.commit
        LgPodPlugin.log_green "Using `#{name}` (#{self.commit})"
      else
        LgPodPlugin.log_green "Using `#{name}`"
      end
      hash_map = LRequest.shared.get_cache_key_params
      # 发现本地有缓存, 不需要更新缓存
      if LRequest.shared.single_git
        need_download = LRequest.shared.cache.find_pod_cache(name, hash_map)
        unless need_download
          hash_map.delete(:commit)
          need_download = LRequest.shared.cache.find_pod_cache(name, hash_map)
        end
      else
        need_download = LRequest.shared.cache.find_pod_cache(name, hash_map)
      end
      if need_download
        LgPodPlugin.log_green "find the new commit of `#{name}`, Git downloading now."
        # 本地 git 下载 pod 目录
        LRequest.shared.git_util.pre_download_git_repository
        hash_map = LRequest.shared.libs[self.name]
        hash_map.delete(:branch) if hash_map
        commit = LRequest.shared.request_params[:commit]
        hash_map[:commit] = commit if commit
      else
        is_delete = LRequest.shared.request_params["is_delete"] ||= false
        LgPodPlugin.log_green "find the cache of `#{name}`, you can use it now."
        hash_map = LRequest.shared.libs[self.name]
        hash_map.delete(:branch) if hash_map
        commit = LRequest.shared.request_params[:commit]
        hash_map[:commit] = commit if commit
        if self.real_name == self.name
          LRequest.shared.libs.delete(self.name) if is_delete
        else
          LRequest.shared.libs.delete(self.real_name) if is_delete
        end
      end

    end

  end

end