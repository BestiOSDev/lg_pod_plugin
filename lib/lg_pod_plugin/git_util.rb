require 'pp'
require 'git'
require_relative 'l_util'
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

    # 根据branch 下载 zip 包
    def git_download_branch_zip(path, temp_name)
      branch = self.branch ||= "master"
      token = LRequest.shared.token
      unless token
        return self.git_clone_by_branch(path, temp_name)
      end
      file_name = "#{temp_name}.zip"
      base_url = self.git[0...self.git.length - 4]
      project_name = base_url.split("/").last
      unless project_name
        return self.git_clone_by_branch(path, temp_name)
      end
      download_url = base_url + "/-/archive/" + branch + "/#{project_name}-#{branch}.zip"
      LgPodPlugin.log_blue "开始下载 => #{download_url}"
      system("curl --header PRIVATE-TOKEN:#{token} -o #{file_name} --connect-timeout 15 #{download_url}")
      unless File.exist?(file_name)
        LgPodPlugin.log_red("下载zip包失败, 尝试git clone #{self.git}")
        return self.git_clone_by_branch(path, temp_name)
      end
      # 解压文件
      result = LUtils.unzip_file(path.join(file_name).to_path, "./")
      new_file_name = "#{project_name}-#{branch}"
      unless result && File.exist?(new_file_name)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_branch(path, temp_name)
      end
      path.join(new_file_name)
    end

    # 通过tag下载zip包
    def git_download_tag_zip(path, temp_name)
      token = LRequest.shared.token
      unless token
        return self.git_clone_by_tag(path, temp_name)
      end
      base_url = self.git[0...self.git.length - 4]
      project_name = base_url.split("/").last
      unless project_name
        return self.git_clone_by_tag(path, temp_name)
      end
      file_name = "#{temp_name}.zip"
      download_url = base_url + "/-/archive/" + self.tag + "/#{project_name}-#{self.tag}.zip"
      # 下载文件
      LgPodPlugin.log_blue "开始下载 => #{download_url}"
      system("curl -s --header PRIVATE-TOKEN:#{token} -o #{file_name} #{download_url}")
      unless File.exist?(file_name)
        LgPodPlugin.log_red("下载zip包失败, 尝试git clone #{self.git}")
        return self.git_clone_by_tag(path, temp_name)
      end
      # 解压文件
      result = LUtils.unzip_file(path.join(file_name).to_path, "./")
      new_file_name = "#{project_name}-#{self.tag}"
      unless result && File.exist?(new_file_name)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_tag(path, temp_name)
      end
      path.join(new_file_name)
    end

    # 通过 commit 下载zip包
    def git_download_commit_zip(path, temp_name)
      token = LRequest.shared.token
      unless token
        return self.git_clone_by_commit(path, temp_name)
      end
      base_url = self.git[0...self.git.length - 4]
      project_name = base_url.split("/").last
      unless project_name
        return self.git_clone_by_commit(path, temp_name)
      end
      file_name = "#{temp_name}.zip"
      download_url = base_url + "/-/archive/" + self.commit + "/#{project_name}-#{self.commit}.zip"
      # 下载文件
      LgPodPlugin.log_blue "开始下载 => #{download_url}"
      system("curl -s --header PRIVATE-TOKEN:#{token} -o #{file_name} #{download_url}")
      unless File.exist?(file_name)
        LgPodPlugin.log_red("下载zip包失败, 尝试git clone #{self.git}")
        return self.git_clone_by_commit(path, temp_name)
      end
      # 解压文件
      result = LUtils.unzip_file(path.join(file_name).to_path, "./")
      new_file_name = "#{project_name}-#{self.commit}"
      unless result && File.exist?(new_file_name)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_commit(path, temp_name)
      end
      path.join(new_file_name)
    end

    def git_clone_by_branch(path, temp_name)
      if self.git && self.branch
        LgPodPlugin.log_blue "git clone --depth=1 --branch #{self.branch} #{self.git}"
        system("git clone --depth=1 -b #{self.branch} #{self.git} #{temp_name}")
      else
        LgPodPlugin.log_blue "git clone --depth=1 #{self.git}"
        system("git clone --depth=1 #{self.git} #{temp_name}")
      end
      path.join(temp_name)
    end

    def git_clone_by_tag(path, temp_name)
      LgPodPlugin.log_blue "git clone --tag #{self.tag} #{self.git}"
      system("git clone --depth=1 -b #{self.tag} #{self.git} #{temp_name}")
      path.join(temp_name)
    end

    def git_clone_by_commit(path, temp_name)
      LgPodPlugin.log_blue "git clone #{self.git}"
      Git.init(temp_name)
      FileUtils.chdir(temp_name)
      system("git remote add origin #{self.git}")
      system("git fetch origin #{self.commit}")
      system("git reset --hard FETCH_HEAD")
      path.join(temp_name)
    end

    # clone 代码仓库
    def git_clone_repository(path)
      FileUtils.chdir(path)
      temp_name = "lg_temp_pod"
      if self.git && self.tag
        if self.git.include?("capp/iOS")
          return git_download_tag_zip(path, temp_name)
        else
          return self.git_clone_by_tag(path, temp_name)
        end
      elsif self.git && self.branch
        if self.git.include?("capp/iOS")
          return self.git_download_branch_zip(path, temp_name)
        else
          return self.git_clone_by_branch(path, temp_name)
        end
      elsif self.git && self.commit
        if self.git.include?("capp/iOS")
          return self.git_download_commit_zip(path, temp_name)
        else
          return self.git_clone_by_commit(path, temp_name)
        end
      elsif self.git
        if self.git.include?("capp/iOS")
          return self.git_download_branch_zip(path, temp_name)
        else
          return self.git_clone_by_branch(path, temp_name)
        end
      end

    end

    # def git_checkout(branch)
    #     system("git checkout -b #{branch}")
    # end
    #
    # def git_switch(branch)
    #     system("git switch #{branch}")
    # end

    #根据git branch commit 返回请求参数用来获取缓存 path
    def get_request_params(git, branch, tag, commit)
      options = { :git => git }
      if git && tag
        options[:tag] = tag
      elsif git && branch
        if commit
          options[:commit] = commit
        else
          new_commit_id = LGitUtil.git_ls_remote_refs(git, branch, nil, commit)
          if new_commit_id
            options[:commit] = new_commit_id
          end
        end
      elsif git && commit
        options[:commit] = commit
      else

      end
      options
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
      if LRequest.shared.single_git
        LgPodPlugin::LCache.cache_pod(self.name, get_temp_folder, { :git => self.git })
      end
      LgPodPlugin::LCache.cache_pod(self.name, get_temp_folder, LRequest.shared.get_cache_key_params)
      FileUtils.chdir(LFileManager.download_director)
      FileUtils.rm_rf(lg_pod_path)
    end

    # 获取最新的一条 commit 信息
    def self.git_ls_remote_refs(git, branch, tag, commit)
      if branch
        LgPodPlugin.log_yellow "git ls-remote #{git} #{branch}"
        new_commit = %x(git ls-remote #{git} #{branch}).split(" ").first
        return [branch, new_commit]
      elsif tag
        LgPodPlugin.log_yellow "git ls-remote #{git}"
        ls = Git.ls_remote(git, :head => true)
        map = ls["tags"]
        keys = map.keys
        idx = keys.index("#{tag}")
        unless idx
          return [nil, nil]
        end
        key = keys[idx]
        new_commit = map[key][:sha]
        return [nil, new_commit]
      else
        if commit
          return nil, commit
        else
          LgPodPlugin.log_yellow "git ls-remote #{git}"
          ls = Git.ls_remote(git, :head => true)
          find_commit = ls["head"][:sha]
          ls["branches"].each do |key, value|
            sha = value[:sha]
            next if sha != find_commit
            return [key, find_commit]
          end
          return nil, find_commit
        end
      end
      # if tag
      #
      # else
      #
      #   # new_commit = new_branch = nil
      #   # find_commit = commit ? commit : ls["head"][:sha]
      #   # unless find_commit
      #   #   return nil, nil
      #   # end
      #   # return nil, find_commit
      # end
    end

    # 本地pod库git操作
    def git_local_pod_check(path)
      FileUtils.chdir(path)
      git = Git.open(Pathname("./"))
      current_branch = git.current_branch
      last_stash_message = "#{current_branch}_pod_install_cache"
      if self.branch == current_branch || !self.branch
        # 是否恢复储藏内容到暂存区
        self.should_pull(git, current_branch)
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
        self.should_pull(git, current_branch)
        # 是否恢复储藏内容到暂存区
        self.should_pop_stash(git, current_branch)
      end
    end

    # 是否pull 代码
    def should_pull(git, branch, new_commit = nil)
      new_branch = branch ||= self.branch
      git_url = git.remote.url ||= self.git
      if new_commit == nil
        _, new_commit = LGitUtil.git_ls_remote_refs(git_url, new_branch, nil, nil)
      end
      local_commit = git.log(1).to_s #本地最后一条 commit hash 值
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
