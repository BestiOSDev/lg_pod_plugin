require 'git'
require_relative 'l_cache'
require_relative 'file_path'

module LgPodPlugin

  class LDownloader

    REQUIRED_ATTRS ||= %i[git name commit branch tag options].freeze
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
      else
        LgPodPlugin.log_green "Using `#{name}`"
      end
      # 发现本地有缓存, 不需要更新缓存
      need_download = LRequest.shared.cache.find_pod_cache(name)
      if need_download
        LgPodPlugin.log_green "find the new commit of `#{name}`, Git downloading now."
        # 本地 git 下载 pod 目录
        LRequest.shared.git_util.pre_download_git_repository
      else
        LRequest.shared.libs.delete(self.name)
        LgPodPlugin.log_green "find the cache of `#{name}`, you can use it now."
      end

      # 本地clone代码失败跳出去
      # unless real_pod_path.exist?
      #   return
      # end
      # # 切换到本地git仓库目录下
      # FileUtils.chdir(real_pod_path)
      # unless real_pod_path.glob("*.git")
      #   return
      # end
      # # 使用branch克隆代码
      # git = Git.open(Pathname("./"))
      # current_branch = git.current_branch
      # if current_branch == branch # 要 clone 的分支正好等于当前分支
      #   current_commit = git.log(1).to_s
      #   if new_commit != current_commit && is_update
      #     #删除旧的pod 缓存
      #     self.cache.clean_old_cache(name, git_url, current_commit)
      #     LgPodPlugin.log_green "git pull #{name} origin/#{current_branch}"
      #     self.git_util.should_pull(git, current_branch, new_commit)
      #     current_commit = new_commit
      #   end
      #   hash_map = { :git => git_url }
      #   if current_commit
      #     hash_map[:commit] = current_commit
      #   end
      #   LSqliteDb.instance.insert_table(name, branch, current_commit, nil, real_pod_path)
      #   LgPodPlugin::LCache.cache_pod(name, real_pod_path, is_update, hash_map)
      # else
      #   branch_exist = git.branches.local.find { |e| e.to_s == branch }
      #   if branch_exist
      #     LgPodPlugin.log_green "git switch #{name} #{git_url} -b #{branch}"
      #     self.git_util.git_switch(branch)
      #   else
      #     LgPodPlugin.log_green "git checkout  #{name} #{git_url} -b #{branch}"
      #     self.git_util.git_checkout(branch)
      #   end
      #   current_commit = git.log(1).to_s
      #   if current_commit != new_commit
      #     LgPodPlugin.log_green "git pull  #{name} #{git_url} -b #{branch}"
      #     self.git_util.should_pull(git, current_branch, new_commit)
      #     current_commit = new_commit
      #   end
      #   hash_map = { :git => git_url }
      #   if current_commit
      #     hash_map[:commit] = current_commit
      #   end
      #   LSqliteDb.instance.insert_table(name, branch, current_commit, nil, real_pod_path)
      #   LgPodPlugin::LCache.cache_pod(name, real_pod_path, is_update, hash_map)
      # end

    end

  end

end