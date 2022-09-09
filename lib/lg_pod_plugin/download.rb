require 'git'
# require 'cocoapods'
require_relative 'database.rb'
require_relative 'cache.rb'
require_relative 'file_path.rb'

module  LgPodPlugin

  class Downloader
    attr_accessor :git_util
    attr_accessor :db
    attr_accessor :cache
    REQUIRED_ATTRS ||= %i[git name commit branch tag options].freeze
    attr_accessor(*REQUIRED_ATTRS)
    def initialize
      self.cache = Cache.new
      self.db = SqliteDb.instance
      super
    end
    def download_init(name, options = {})
      self.name = name
      self.options = options
      self.git = options[:git]
      self.tag = options[:tag]
      self.branch = options[:branch]
      self.commit = options[:commit]
    end

    def check_cache_valid(name, branch)
      self.db.should_clean_pod_info(name, branch)
    end

    # 预下载处理
    def pre_download_pod(git)
      self.git_util = git
      self.git_util.git_init(self.name, self.options)
      if name == "LAddressComponents" || name == "LLogger" || name == "LUnityFramework" || name == "LUser"
        pp name
      end
      # tag = options[:tag]
      git_url = options[:git]
      # commit = options[:commit]
      branch = options[:branch]

      # 发现本地有缓存, 不需要更新缓存
      need_download, new_commit = self.cache.find_pod_cache(name, git_url, branch)
      unless need_download
        puts "find the cache of `#{name}`, you can use it now."
        return
      end

      # 检查是否要清空缓存
      check_cache_valid(name, branch)

      # 本地 git 下载 pod 目录
      pre_down_load_path = self.cache.get_download_path(name, git_url, branch)
      real_pod_path = self.git_util.pre_download_git_remote(pre_down_load_path, branch)
      # 本地clone代码失败跳出去
      unless real_pod_path.exist?
        return
      end
      # 切换到本地git仓库目录下
      FileUtils.chdir(real_pod_path)
      unless real_pod_path.glob("*.git")
        return
      end
      # 使用branch克隆代码
      git = Git.open(Pathname("./"))
      current_branch = git.current_branch
      if current_branch == branch # 要 clone 的分支正好等于当前分支
        current_commit = git.log(1).to_s
        if new_commit != current_commit
          #删除旧的pod 缓存
          self.cache.clean_old_cache(name, git_url, current_commit)
          puts "git pull #{name} origin/#{current_branch}\n"
          self.git_util.should_pull(git, current_branch, new_commit)
          current_commit = new_commit
        end
        hash_map = {:git => git_url}
        if current_commit
          hash_map[:commit] = current_commit
        end
        SqliteDb.instance.insert_table(name, branch, current_commit, nil, real_pod_path)
        LgPodPlugin::Cache.cache_pod(name,real_pod_path, hash_map)
      else
        branch_exist = git.branches.local.find {|e| e.to_s == branch}
        if branch_exist
          puts "git switch #{name} #{git_url} -b #{branch}\n"
          self.git_util.git_switch(branch)
        else
          puts "git checkout  #{name} #{git_url} -b #{branch}\n"
          self.git_util.git_checkout(branch)
        end
        current_commit = git.log(1).to_s
        if current_commit != new_commit
          puts "git pull  #{name} #{git_url} -b #{branch}\n"
          self.git_util.should_pull(git, current_branch, new_commit)
          current_commit = new_commit
        end
        hash_map = {:git => git_url}
        if current_commit
          hash_map[:commit] = current_commit
        end
        SqliteDb.instance.insert_table(name, branch, current_commit, nil, real_pod_path)
        LgPodPlugin::Cache.cache_pod(name,real_pod_path, hash_map)
      end


    end

  end

end