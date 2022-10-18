require 'pp'
require 'git'
require_relative 'l_config'
require_relative 'l_util'
require_relative 'request'
require_relative 'l_cache'
require_relative 'net-ping'
require_relative 'database'
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
            return git_archive.git_clone_by_tag(path, temp_name)
          end
        rescue
          return git_archive.git_clone_by_tag(path, temp_name)
        end
      elsif self.git && self.branch
        begin
          if LUtils.is_use_gitlab_archive_file(self.git)
            return git_archive.gitlab_download_branch_zip(path, temp_name)
          elsif self.git.include?("https://github.com")
            return git_archive.github_download_branch_zip path, temp_name
          else
            return git_archive.git_clone_by_branch(path, temp_name)
          end
        rescue
          return git_archive.git_clone_by_branch(path, temp_name)
        end
      elsif self.git && self.commit
        if LUtils.is_use_gitlab_archive_file(self.git)
          return git_archive.gitlab_download_commit_zip(path, temp_name)
        elsif self.git.include?("https://github.com")
          return git_archive.github_download_commit_zip path, temp_name
        else
          return git_archive.git_clone_by_commit(path, temp_name)
        end
      elsif self.git
        if LUtils.is_use_gitlab_archive_file(self.git)
          return git_archive.gitlab_download_branch_zip(path, temp_name)
        elsif self.git.include?("https://github.com")
          return git_archive.github_download_branch_zip path, temp_name
        else
          return git_archive.git_clone_by_branch(path, temp_name)
        end
      end

    end

    # git 预下载
    def pre_download_git_repository
      temp_path = LFileManager.download_director.join("temp")
      FileUtils.rm_rf(temp_path) if temp_path.exist?
      lg_pod_path = LRequest.shared.cache.cache_root
      lg_pod_path.mkdir(0700) unless lg_pod_path.exist?
      get_temp_folder = git_clone_repository(lg_pod_path)
      #下载 git 仓库失败
      return nil unless (get_temp_folder && get_temp_folder.exist?)
      LgPodPlugin::LCache.cache_pod(self.name, get_temp_folder, { :git => self.git }) if LRequest.shared.single_git
      LgPodPlugin::LCache.cache_pod(self.name, get_temp_folder, LRequest.shared.get_cache_key_params)
      FileUtils.chdir(LFileManager.download_director)
      FileUtils.rm_rf(lg_pod_path)
    end

    # 获取最新的一条 commit 信息
    def self.git_ls_remote_refs(name,git, branch, tag, commit)
      ip = LRequest.shared.net_ping.ip
      network_ok = LRequest.shared.net_ping.network_ok
      return [nil, nil] unless (ip && network_ok)
      if branch
        LgPodPlugin.log_blue "git ls-remote #{git} #{branch}"
        begin
          result = %x(timeout 5 git ls-remote #{git} #{branch})
        rescue
          result = %x(git ls-remote #{git} #{branch})
        end
        unless result && result != ""
          id = LPodLatestRefs.get_pod_id(name, git)
          pod_info = LSqliteDb.shared.query_pod_refs(id)
          new_commit = pod_info.commit if pod_info
          return [branch, new_commit]
        end
        new_commit, new_branch = LUtils.commit_from_ls_remote(result, branch)
        if new_commit
          LSqliteDb.shared.insert_pod_refs(name, git, branch, tag, new_commit)
        end
        return [branch, new_commit]
      elsif tag
        LgPodPlugin.log_blue "git ls-remote --tags #{git}"
        begin
          result = %x(timeout 5 git ls-remote --tags #{git})
        rescue
          result = %x(git ls-remote --tags #{git})
        end
        unless result && result != ""
          id = LPodLatestRefs.get_pod_id(name, git)
          pod_info = LSqliteDb.shared.query_pod_refs(id)
          new_commit = pod_info.commit if pod_info
          new_branch = pod_info.branch if pod_info
          return [new_branch, new_commit]
        end
        new_commit, new_branch = LUtils.commit_from_ls_remote(result, tag)
        if new_commit
          LSqliteDb.shared.insert_pod_refs(name, git, branch, tag, new_commit)
        end
        return [new_branch, new_commit]
      elsif commit
        return nil, commit
      else
        LgPodPlugin.log_blue "git ls-remote #{git}"
        begin
          result = %x(timeout 5 git ls-remote -- #{git})
        rescue
          result = %x(git ls-remote -- #{git})
        end
        unless result && result != ""
          id = LPodLatestRefs.get_pod_id(name, git)
          pod_info = LSqliteDb.shared.query_pod_refs(id)
          new_commit = pod_info.commit if pod_info
          new_branch = pod_info.branch if pod_info
          return [new_branch, new_commit]
        end
        new_commit, new_branch = LUtils.commit_from_ls_remote(result, "HEAD")
        if new_commit
          LSqliteDb.shared.insert_pod_refs(name, git, new_branch, tag, new_commit)
        end
        return [new_branch, new_commit]
      end
    end

  end

end
