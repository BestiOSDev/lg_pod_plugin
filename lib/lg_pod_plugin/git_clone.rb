require 'git'
require 'pp'
require 'cocoapods'
require_relative 'cache'
require_relative 'file_path'
require_relative 'git_info'


module LgPodPlugin

  class GitHelper

    def self.git_clone(name ,git_url, branch)
      if branch
        temp_git_path = "l-temp-pod"
        puts "git clone #{name} #{branch} #{git_url}"
        Git.clone(git_url, Pathname(temp_git_path),branch: branch, depth: 1)
        git_info = GitRepositoryInfo.new(name, (Dir.pwd + "/#{temp_git_path}"))
        Dir.chdir(temp_git_path)
        system("echo \"branch:#{branch}\" >> git_log.txt")
        system("echo git_log.txt >> .gitignore")
        Dir.chdir("..")
        return git_info
      else
        return nil
      end
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

    def self.mv_git_directory_to_root(old_name, new_name)
      system("mv #{old_name} #{new_name}")
    end

    def self.read_log_txt
      log_txt_path = './git_log.txt'
      unless File::exist?(log_txt_path)
        return nil
      end
      log_txt = File.open(log_txt_path, 'r:utf-8', &:read)
      if log_txt.respond_to?(:encoding) && log_txt.encoding.name != 'UTF-8'
        contents.encoding("UTF-8")
      end
      if log_txt.include?("\n")
        log_txt = log_txt.delete("\n")
      end
      return log_txt
    end

    def self.init_pod_path(name, git_url, branch)
      root_path = FileManager.download_director
      lg_pod_path =  FileManager.download_pod_path(name)
      if File::exist?(lg_pod_path)
        Dir.chdir(lg_pod_path)
        log_txt = self.read_log_txt
        # 判断当前branch是否缓存过代码
        if branch && log_txt == "branch:#{branch}"
          git_info = GitRepositoryInfo.new(name, nil)
          git_info.set_pod_path(lg_pod_path)
          git_info.set_log(log_txt)
          return git_info
        else
          FileUtils.rm_r(lg_pod_path)
        end
      end
      Dir.chdir(root_path)
      temp_path = root_path + "/tmp"
      if File::exist?(temp_path)
        FileUtils.rm_r(temp_path)
      end
      FileUtils.mkdir(temp_path)
      FileUtils.chdir(temp_path)
      #clone仓库
      git_info = git_clone(name, git_url, branch)
      get_temp_folder = git_info.get_temp_folder ||= ""
      #下载 git 仓库失败
      if get_temp_folder == nil || get_temp_folder == ""
        return git_info
      end
      #对仓库目录重命名
      old_name = git_info.get_temp_folder
      mv_git_directory_to_root(old_name, lg_pod_path)
      Dir.chdir(lg_pod_path)
      log_txt = self.read_log_txt
      git_info.set_log(log_txt)
      # 删除临时目录
      FileUtils.rm_r(temp_path)
      git_info.set_pod_path(lg_pod_path)
      return git_info
    end

    # git 预下载
    def self.git_pre_downloading(name, options = {})
      # if name == "l-mapKit-iOS" || name == "LLogger" || name == "LUnityFramework" || name == "LUser"
      #   pp name
      # end
      # tag = options[:tag]
      git_url = options[:git]
      # commit = options[:commit]
      branch = options[:branch]
      # 本地 git 下载 pod 目录
      git_info = self.init_pod_path(name , git_url, branch)
      lg_pod_path = git_info.get_pod_path ||= FileManager.download_pod_path(name)
      # 本地clone代码失败跳出去
      unless File::exist?(lg_pod_path)
        return
      end
      # 切换到本地git仓库目录下
      Dir.chdir(lg_pod_path)
      unless File.exist?(".git")
        return
      end
      # 使用branch克隆代码
      git = Git.open(Pathname("./"))
      if git == nil
        return
      end
      current_branch = git.current_branch
      if current_branch == branch # 要 clone 的分支正好等于当前分支
        puts "git fetch #{name} origin/#{current_branch}\n"
        diff = git.fetch.to_s
        if diff != ""
          puts "git pull #{name} origin/#{current_branch}\n"
          git_pull(branch)
        end
        commit = git.log(1).to_s
        hash_map = {:git => git_url}
        if commit
          hash_map[:commit] = commit
        end
        LgPodPlugin::Cache.cache_pod(name,lg_pod_path, hash_map)
      else
        local_branches = git.branches.local.map { |s|
          s.to_s
        }
        if local_branches.include?(branch)
          puts "git switch #{name} #{git_url} -b #{branch}\n"
          git_switch(branch)
        else
          puts "git checkout  #{name} #{git_url} -b #{branch}\n"
          git_checkout(branch)
        end
        puts "git pull  #{name} #{git_url} -b #{branch}\n"
        git_pull(branch)
        commit = git.log(1).to_s
        hash_map = {:git => git_url}
        if commit
          hash_map[:commit] = commit
        end
          LgPodPlugin::Cache.cache_pod(name,lg_pod_path, hash_map)
      end

    end

    # 判断本地是否有 待检出目标分支, 如果存在就拉取代码 , 不存在 checkout 出来目标 branch
    # @param [Object] branch
    def self.install_local_pod(branch)
      git = Git.open(Pathname("./"))
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
          # "当前#{current_branch}分支有未暂存的内容"
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
