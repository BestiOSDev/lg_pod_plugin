require 'pp'
require 'git'
require_relative 'l_config'
require_relative 'l_util'
require_relative 'request'
require_relative 'l_cache'
require_relative 'gitlab_archive'

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
    # git clone commit
    def git_clone_by_commit(path, temp_name)
      Git.init(temp_name)
      FileUtils.chdir(temp_name)
      LgPodPlugin.log_blue "git clone #{self.git}"
      system("git remote add origin #{self.git}")
      system("git fetch origin #{self.commit}")
      system("git reset --hard FETCH_HEAD")
      path.join(temp_name)
    end

    # clone 代码仓库
    def git_clone_repository(path)
      FileUtils.chdir(path)
      temp_name = "lg_temp_pod"
      git_archive = GitLabArchive.new(self.name, self.git, self.branch, self.tag, self.commit)
      if self.git && self.tag
        begin
          if LUtils.is_use_gitlab_archive_file(self.git)
            return git_archive.gitlab_download_tag_zip(path, temp_name)
          elsif self.git.include?("https://github.com")
            return git_archive.github_download_tag_zip path, temp_name
          else
            return self.git_clone_by_tag(path, temp_name)
          end
        rescue
          return self.git_clone_by_tag(path, temp_name)
        end
      elsif self.git && self.branch
        begin
          if LUtils.is_use_gitlab_archive_file(self.git)
            return git_archive.gitlab_download_branch_zip(path, temp_name)
          elsif self.git.include?("https://github.com")
            return git_archive.github_download_branch_zip path, temp_name
          else
            return self.git_clone_by_branch(path, temp_name)
          end
        rescue
          return self.git_clone_by_branch(path, temp_name)
        end
      elsif self.git && self.commit
        if LUtils.is_use_gitlab_archive_file(self.git)
          return git_archive.gitlab_download_commit_zip(path, temp_name)
        elsif self.git.include?("https://github.com")
          return git_archive.github_download_commit_zip path, temp_name
        else
          return self.git_clone_by_commit(path, temp_name)
        end
      elsif self.git
        if LUtils.is_use_gitlab_archive_file(self.git)
          return git_archive.gitlab_download_branch_zip(path, temp_name)
        elsif self.git.include?("https://github.com")
          return git_archive.github_download_branch_zip path, temp_name
        else
          return self.git_clone_by_branch(path, temp_name)
        end
      end

    end

    # git 预下载
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
        result = %x(git ls-remote #{git} #{branch})
        new_commit = result.split(" ").first if result
        return [branch, new_commit]
      elsif tag
        LgPodPlugin.log_yellow "git ls-remote #{git}"
        ls = Git.ls_remote(git, :head => true)
        map = ls["tags"]
        keys = map.keys
        idx = keys.index("#{tag}")
        return [nil, nil] unless idx
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

    end

  end
end