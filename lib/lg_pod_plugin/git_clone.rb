require 'git'
require 'pp'
require 'cocoapods'
require_relative 'cache'
require_relative 'file_path'


module LgPodPlugin

  class GitHelper
    #初始化 git 仓库
    def self.git_init(git_url, branch)
      system("git init")
      system("git remote add -f origin #{git_url}")
      system("git config core.sparsecheckout false")
      git_checkout(branch)
    end

    # 检出 branch
    def self.git_checkout(branch)
      system("git checkout #{branch}")
    end

    # git 切换分支
    def self.git_switch(branch)
      system("git switch  #{branch}")
    end

    #拉取分支代码
    def self.git_pull(branch)
      system("git pull origin #{branch}")
    end

    # git 预下载
    def self.git_pre_downloading(name, git_url, branch, commit)
      # 本地 git 下载 pod 目录
      lg_pod_path = FileManager.download_pod_path(name)
      # system("open #{lg_pod_path}")
      Dir.chdir(lg_pod_path)
      unless File.directory?(".git")
        git_init(git_url, branch)
      end
      commit_id = nil
      git = Git.open('./')
      current_branch = git.current_branch
      if current_branch == branch # 要 clone 的分支正好等于当前分支
        pp "git pull #{git_url} -b #{branch}"
        git_pull(branch)
        commit_id = git.log(1).to_s
        pp "git log #{git_url} -commit #{commit_id}"
        hash_map = {:git => git_url}
        if commit_id != nil
          hash_map[:commit] = commit_id
        end
        LgPodPlugin::Cache.cache_pod(name,lg_pod_path, hash_map)
      else
        local_branchs = git.branches.local.map { |s|
          s.to_s
        }
        if local_branchs.include?(branch)
          pp "git switch #{git_url} -b #{branch}"
          git_switch(branch)
        else
          pp "git checkout #{git_url} -b #{branch}"
          git_checkout(branch)
          # system("git checkout -b #{branch}")
        end
        pp "git pull #{git_url} -b #{branch}"
        git_pull(branch)
        # git.pull(git.repo, branch)
        commit_id = git.log(1).to_s
        hash_map = {:git => git_url}
        if commit_id != nil
          hash_map[:commit] = commit_id
        end
        LgPodPlugin::Cache.cache_pod(name,lg_pod_path, hash_map)
      end

    end

    # 判断本地是否有 待检出目标分支, 如果存在就拉取代码 , 不存在 checkout 出来目标 branch
    # @param [Object] branch
    def self.install_local_pod(branch)
      git = Git.open('./')
      current_branch = git.current_branch
      last_stash_message = "#{current_branch}_pod_install_cache"
      if branch == current_branch
        # git stash save
        git.pull(git.repo, branch)
      else
        # 存储上一个 branch 未暂存的内容
        # 判断 git status 是否有要暂存的内容
        have_changes = git.status.changed.map { |change|
          change.to_s
        }
        # 如果有要暂存的内容, 就 git stash save
        if have_changes.count.positive?
          # pp "当前#{current_branch}分支有未暂存的内容"
          git.branch.stashes.save(last_stash_message)
        end
        # 这里 checkout到目标分支, 本地有git switch -b xxx, 本地没有 git checkout -b xxx
        git.checkout(git.branch(branch))
        git.pull(git.repo, branch)
        current_branch = git.current_branch
        last_stash_message = "#{current_branch}_pod_install_cache"
        # 查看下贮存的有没有代码
        stash_names = git.branch.stashes.all
        if stash_names.count.positive?
          drop_index = nil # 需要 pop 那个位置索引
          stash_names.each do |each|
            next unless each.include?(last_stash_message)
            # 恢复上次贮藏的代码
            drop_index = "#{stash_names.index(each)}"
            git.branch.stashes.apply
          end

          # 清空上一次贮存的代码
          unless drop_index.nil?
            # ruby_git并没有封装删除单个stash api, 使用原生 git 命令删除指定位置索引的 stash
            git_command = "git stash drop stash@{" + drop_index + "}"
            system(git_command)
          end

        end

      end

    end

  end

end
