require 'pp'
require 'git'
require_relative 'request'
require_relative 'l_cache'

module LgPodPlugin

  class LGitUtil

    REQUIRED_ATTRS ||= %i[git tag path name commit branch].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(name, options = {})
      self.name = name
      self.git = options[:git]
      self.tag = options[:tag]
      self.path = options[:path]
      self.branch = options[:branch]
      self.commit = options[:commit]
    end

    def git_clone_repository(path)
      FileUtils.chdir(path)
      temp_name = "lg_temp_pod"
      if self.git && self.tag
        LgPodPlugin.log_blue "git clone  --tag #{self.tag} #{self.git}"
        system("git clone --depth 1 -b #{self.tag} #{self.git} #{temp_name}")
      else
        LgPodPlugin.log_blue "git clone --depth 1 --branch #{self.branch} #{self.git}"
        system("git clone --depth 1 --branch #{self.branch} #{self.git} #{temp_name}")
      end
      return path.join(temp_name)
    end

    # def git_checkout(branch)
    #     system("git checkout -b #{branch}")
    # end
    #
    # def git_switch(branch)
    #     system("git switch #{branch}")
    # end

    def request_params
      hash_map = {:git => git}
      if git && tag
        hash_map[:tag] = tag
        hash_map[:commit] = self.commit
      else
        hash_map[:commit] = commit
      end
      return hash_map
    end

    def pre_download_git_repository
      temp_path = LFileManager.download_director.join("temp")
      if temp_path.exist?
        FileUtils.rm_rf(temp_path)
      end
      lg_pod_path = LRequest.shared.cache.cache_root
      unless lg_pod_path.exist?
        lg_pod_path.mkdir(0700)
      end
      get_temp_folder = git_clone_repository(lg_pod_path)
      #下载 git 仓库失败
      unless get_temp_folder.exist?
        return nil
      end
      LgPodPlugin::LCache.cache_pod(self.name, get_temp_folder, true, self.request_params)
      FileUtils.mkdir(temp_path)
      lg_pod_path.rename(temp_path)
    end

    # 本地pod库git操作
    def git_local_pod_check(path)
      FileUtils.chdir(path)
      git = Git.open(Pathname("./"))
      current_branch = git.current_branch
      last_stash_message = "#{current_branch}_pod_install_cache"
      if self.branch == current_branch || !self.branch
        # 是否恢复储藏内容到暂存区
        self.should_pull(git ,current_branch)
      else
        # 存储上一个 branch 未暂存的内容
        # 判断 git status 是否有要暂存的内容
        have_changes = git.status.changed.map { |change|
          change.to_s
        }
        # 如果有要暂存的内容, 就 git stash save
        unless have_changes.empty?
          # "当前#{current_branch}分支有未暂存的内容"
          git.branch.stashes.save(last_stash_message)
        end
        # 这里 checkout到目标分支, 本地有git switch -b xxx, 本地没有 git checkout -b xxx
        git.checkout(git.branch(branch))
        current_branch = git.current_branch
        self.should_pull(git ,current_branch)
        # 是否恢复储藏内容到暂存区
        self.should_pop_stash(git, current_branch)
      end
    end

    # 获取最新的一条 commit 信息
    def self.git_ls_remote_refs(git, branch, tag)
      if branch
        LgPodPlugin.log_yellow "git ls-remote #{git} #{branch}"
        commit = %x(git ls-remote #{git} #{branch}).split(" ").first
        return [branch, commit]
      end
      ls = Git.ls_remote(git, :head => true )
      if tag
        commit = ls["tags"]["#{tag}"][:sha]
        return [nil, commit]
      else
        commit = ls["head"][:sha]
        ls["branches"].each do |key, value|
          sha = value[:sha]
          next if sha != commit
          return [key, commit]
          break
        end
      end
    end

    # 是否pull 代码
    def should_pull(git, branch, new_commit = nil)
      git_url = git.remote.url
      if new_commit == nil
        new_commit = LGitUtil.git_ls_remote_refs(git_url, branch,nil )
      end
      local_commit = git.log(1).to_s  #本地最后一条 commit hash 值
      if local_commit != new_commit
        system("git pull origin #{branch}")
      end
    end

    def should_pop_stash(git, branch)
      last_stash_message = "#{branch}_pod_install_cache"
      # 查看下贮存的有没有代码
      stashes = git.branch.stashes.all.flatten.select do |ss|
        ss.is_a?(String)
      end
      unless stashes.include?(last_stash_message)
        return
      end
      drop_index = stashes.index(last_stash_message)
      # 恢复上次贮藏的代码
      system("git stash apply stash@{#{drop_index}} ")
      # pop 掉已恢复到暂缓区的代码
      git_command = "git stash drop stash@{" + "#{drop_index}" + "}"
      system(git_command)
    end

  end
end
