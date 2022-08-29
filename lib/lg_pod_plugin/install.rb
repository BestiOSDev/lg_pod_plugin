require 'pp'
require 'git'
require 'cocoapods'

module LgPodPlugin
  class Installer

    # 判断本地是否有 待检出目标分支, 如果存在就拉取代码 , 不存在 checkout 出来目标 branch
    # @param [Object] branch
    def self.git_switch(branch)
      git = Git.open('./')
      current_branch = git.current_branch
      last_stash_message = "#{current_branch}_pod_install_cache"
      if branch == current_branch
        # git stash save
        git.pull(git.repo, branch)
      elsif
        # 存储上一个 branch 未暂存的内容
        # 判断 git status 是否有要暂存的内容
       have_changes = git.status.changed.map { |change|
         change.to_s
       }
        # 如果有要暂存的内容, 就 git stash save
        unless have_changes.empty?
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
        unless stash_names.empty?
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

    # @param [Object] name
    # @param [Object] target
    # @param [Hash] options
    # @return [Object] nil
    def self.pod(name, target, options = {})
      path = options[:path]
      branch = options[:branch]
      if !path.nil? && File.directory?(path)
        # 找到本地组件库 执行 git pull
        Dir.chdir(path) do
          git_switch(branch)
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
        target.store_pod(name, hash_map)
      else
        target.store_pod(name, options)
      end

    end
  end
end
