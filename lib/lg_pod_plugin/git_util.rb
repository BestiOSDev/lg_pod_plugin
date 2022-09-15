require 'pp'
require 'git'
require_relative 'cache'

module LgPodPlugin

  class GitUtil
    # attr_accessor :git
    # attr_accessor :tag
    # attr_accessor :path
    # attr_accessor :name
    # attr_accessor :commit
    # attr_accessor :branch
    # attr_accessor :temp_git_path
    REQUIRED_ATTRS ||= %i[git tag path name commit branch temp_git_path is_cache].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize
      super
    end

    def git_init(name, options = {})
      self.name = name
      self.git = options[:git]
      self.tag = options[:tag]
      self.path = options[:path]
      self.branch = options[:branch]
      self.commit = options[:commit]
      self.is_cache = options[:depth]
    end

    def git_clone(path)
      if self.branch
        temp_git_path = path.join("l-temp-pod")
        LgPodPlugin.log_green "git clone --template= --single-branch --depth 1 --branch #{self.branch} #{self.git}"
        system("git clone --template= --single-branch --depth 1 --branch #{self.branch} #{self.git} #{temp_git_path}")
        temp_git_path
      else
         nil
      end
    end

    def git_checkout(branch)
        system("git checkout -b #{branch}")
    end
    
    def git_switch(branch)
        system("git switch #{branch}")
    end

    #noinspection RubyNilAnalysis
    def pre_download_git_remote(path, branch)
      lg_pod_path = Pathname(path)
      root_path = FileManager.download_director
      pod_info_db = SqliteDb.instance.select_table(self.name, branch)
      if lg_pod_path.exist? && pod_info_db.branch
        return lg_pod_path
      end

      FileUtils.chdir(root_path)
      temp_path = root_path.join("temp")
      if temp_path.exist?
        FileUtils.rm_r(temp_path)
      end
      temp_path.mkdir(0700)
      FileUtils.chdir(temp_path)
      #clone仓库
      get_temp_folder = git_clone(temp_path)
      #下载 git 仓库失败
      unless get_temp_folder.exist?
        return nil
      end

      if self.is_cache
        pod_root_director = FileManager.download_pod_path(name)
        unless pod_root_director.exist?
          FileUtils.mkdir(pod_root_director)
        end
        FileUtils.mv(get_temp_folder, lg_pod_path)
        temp_path.rmdir
        lg_pod_path
      else
        commit = GitUtil.git_ls_remote_refs(self.git, self.branch)
        LgPodPlugin::Cache.cache_pod(self.name, get_temp_folder, true, {:git => self.git, :commit => commit})
        system("cd ..")
        system("rm -rf #{get_temp_folder.to_path}")
        return lg_pod_path
      end

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
    def self.git_ls_remote_refs(git, branch)
      last_commit = nil
      LgPodPlugin.log_green "git ls-remote #{git} #{branch}"
      sha = %x(git ls-remote #{git} #{branch}).split(" ").first
      if sha
        last_commit = sha
        return last_commit
      else
        ls = Git.ls_remote(git, :refs => true )
        find_branch = ls["branches"][branch]
        if find_branch
          last_commit = find_branch[:sha]
          return last_commit
        end
        return nil
      end
    end

    # 是否pull 代码
    def should_pull(git, branch, new_commit = nil)
      git_url = git.remote.url
      if new_commit == nil
        new_commit = GitUtil.git_ls_remote_refs(git_url, branch)
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
