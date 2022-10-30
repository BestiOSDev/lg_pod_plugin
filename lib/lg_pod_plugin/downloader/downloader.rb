require 'git'
require_relative '../git/http_download'

module LgPodPlugin

  class LDownloader
    attr_accessor :request

    def initialize(pod)
      self.request = LRequest.new(pod)
    end

    # 预下载处理
    def pre_download_pod
      name = self.request.name
      checkout_options = Hash.new.merge!(self.request.checkout_options)
      http = checkout_options[:http]
      git = checkout_options[:git]
      tag = checkout_options[:tag]
      branch = checkout_options[:branch]
      commit = checkout_options[:commit] ||= self.request.params[:commit]
      if branch
        LgPodPlugin.log_green "Using `#{name}` (#{branch})"
      elsif tag
        LgPodPlugin.log_green "Using `#{name}` (#{tag})"
      elsif commit
        LgPodPlugin.log_green "Using `#{name}` (#{commit})"
      elsif http
        version = checkout_options[:version]
        LgPodPlugin.log_green "Using `#{name}` (#{version})"
      else
        LgPodPlugin.log_green "Using `#{name}`"
      end
      hash_map = self.request.get_cache_key_params
      # 发现本地有缓存, 不需要更新缓存
      if self.request.single_git
        need_download = LCache.new.find_pod_cache(name, hash_map, self.request.spec, self.request.released_pod)
        unless need_download
          hash_map.delete(:commit)
          need_download = LCache.new.find_pod_cache(name, hash_map, self.request.spec, self.request.released_pod)
        end
      else
        need_download = LCache.new.find_pod_cache(name, hash_map, self.request.spec, self.request.released_pod)
      end
      if need_download
        LgPodPlugin.log_green "find the new commit of `#{name}`, Git downloading now."
        # 本地 git 下载 pod 目录
        download_params = self.pre_download_git_repository name, git, branch, tag, commit, http
        if download_params && download_params.is_a?(Hash)
          return download_params
        end
        self.request.checkout_options.delete(:branch) if commit
        self.request.checkout_options[:commit] = commit if commit
      else
        is_delete = self.request.params["is_delete"] ||= false
        LProject.shared.need_update_pods.delete(name) if is_delete
        LgPodPlugin.log_green "find the cache of `#{name}`, you can use it now."
        self.request.checkout_options.delete(:branch) if commit
        self.request.checkout_options[:commit] = commit if commit
        return nil
      end

    end

    def pre_download_git_repository(name, git, branch, tag, commit, http = nil)
      temp_path = LFileManager.download_director.join("temp")
      FileUtils.rm_rf(temp_path) if temp_path.exist?
      lg_pod_path = LFileManager.cache_workspace(LProject.shared.workspace)
      lg_pod_path.mkdir(0700) unless lg_pod_path.exist?
      get_temp_folder = select_git_repository_download_strategy(lg_pod_path, name, git, branch, tag, commit, true ,http)
      return nil unless get_temp_folder
      if get_temp_folder.is_a?(Hash)
        return get_temp_folder
      end
      #下载 git 仓库失败
      return nil unless get_temp_folder&.exist?
      LgPodPlugin::LCache.cache_pod(name, get_temp_folder, { :git => git }, self.request.spec, self.request.released_pod) if self.request.single_git
      LgPodPlugin::LCache.cache_pod(name, get_temp_folder, self.request.get_cache_key_params, self.request.spec, self.request.released_pod)
      FileUtils.chdir(LFileManager.download_director)
      FileUtils.rm_rf(lg_pod_path)
      return nil
    end

    # 根据不同 git 源 选择下载策略
    def select_git_repository_download_strategy(path, name, git, branch, tag, commit, async = true, http = nil)
      FileUtils.chdir(path)
      temp_name = "lg_temp_pod"
      new_branch = branch ? branch : self.request.params[:branch]
      git_archive = GitLabArchive.new(name, git, new_branch, tag, commit, self.request.config)
      if http
        begin
          return LgPodPlugin::HTTPDownloader.http_download_with path, "#{temp_name}.zip", http, async
        rescue
          return nil
        end
      elsif git && tag
        begin
          if is_use_gitlab_archive_file(git)
            return git_archive.gitlab_download_tag_zip(path, temp_name, async)
          elsif git.include?("https://github.com")
            return git_archive.github_download_tag_zip path, temp_name, async
          else
            return git_archive.git_clone_by_tag(path, temp_name)
          end
        rescue
          return git_archive.git_clone_by_tag(path, temp_name)
        end
      elsif git && new_branch
        begin
          if is_use_gitlab_archive_file(git)
            return git_archive.gitlab_download_branch_zip(path, temp_name, new_branch, async)
          elsif git.include?("https://github.com")
            return git_archive.github_download_branch_zip path, temp_name, new_branch, async
          else
            return git_archive.git_clone_by_branch(path, temp_name, new_branch)
          end
        rescue
          return git_archive.git_clone_by_branch(path, temp_name, new_branch)
        end
      elsif git && commit
        begin
          if is_use_gitlab_archive_file(git)
            return git_archive.gitlab_download_commit_zip(path, temp_name, async)
          elsif git.include?("https://github.com")
            return git_archive.github_download_commit_zip path, temp_name, async
          else
            return git_archive.git_clone_by_commit(path, temp_name)
          end
        rescue
          return git_archive.git_clone_by_commit(path, temp_name)
        end
      elsif git
        begin
          if is_use_gitlab_archive_file(git)
            return git_archive.gitlab_download_branch_zip(path, temp_name, new_branch, async)
          elsif git.include?("https://github.com")
            return git_archive.github_download_branch_zip path, temp_name, new_branch, async
          else
            return git_archive.git_clone_by_branch(path, temp_name, new_branch)
          end
        rescue
          return git_archive.git_clone_by_branch(path, temp_name, new_branch)
        end
      else
        return nil
      end
    end

    # 是否能够使用 gitlab 下载 zip 文件
    def is_use_gitlab_archive_file(git)
      return false if git.include?("https://github.com") || git.include?("https://gitee.com")
      config = self.request.config
      return false if (!config || !config.access_token)
      return true if config.project
      project_name = LUtils.get_git_project_name(git)
      config.project = GitLabAPI.request_project_info(config.host, project_name, config.access_token, git)
      (config.project != nil)
    end


  end

end
