require 'git'
require 'cocoapods-core'
require_relative '../git/http_download'
require_relative '../git/git_download'

module LgPodPlugin

  class LDownloader
    attr_accessor :request

    def initialize(pod)
      self.request = LRequest.new(pod)
    end

    # 预下载处理
    def pre_download_pod
      name = self.request.name
      if self.request.lg_spec
        podspec = self.request.lg_spec.spec
      else
        podspec = nil
      end
      checkout_options = Hash.new.merge!(self.request.checkout_options)
      http = checkout_options[:http]
      git = checkout_options[:git]
      tag = checkout_options[:tag]
      branch = checkout_options[:branch]
      checkout_options[:name] = name if name
      checkout_options[:spec] = self.request.lg_spec if podspec
      unless branch
        branch = self.request.params[:branch] if self.request.params[:branch]
        checkout_options[:branch] = branch if branch
      end
      commit = checkout_options[:commit]
      unless commit
        commit = self.request.params[:commit] if self.request.params[:commit]
        checkout_options[:commit] = commit if commit
      end
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
        pod_is_exist, destination, cache_pod_spec = LCache.new.pod_cache_exist(name, hash_map, podspec, self.request.released_pod)
      else
        pod_is_exist, destination, cache_pod_spec = LCache.new.pod_cache_exist(name, hash_map, podspec, self.request.released_pod)
      end
      if pod_is_exist
        is_delete = self.request.params["is_delete"] ||= false
        LProject.shared.need_update_pods.delete(name) if is_delete
        self.request.checkout_options.delete(:branch) if commit
        self.request.checkout_options[:commit] = commit if commit
        LgPodPlugin.log_green "find the cache of `#{name}`, you can use it now."
         nil
      else
        LgPodPlugin.log_green "find the new commit of `#{name}`, Git downloading now."
        # 本地 git 下载 pod 目录
        download_params = self.pre_download_git_repository(checkout_options)
        if download_params && download_params.is_a?(Hash)
          download_params["destination"] = destination
          download_params["cache_pod_spec_path"] = cache_pod_spec
          podspec = download_params["podspec"]
          podspec_content = download_params["podspec_content"]
          if podspec
            podspec_json = podspec.to_pretty_json
            download_params["podspec_json"] = podspec_json if podspec
            download_params["prepare_command"] = podspec.prepare_command if podspec
            download_params.delete("podspec")
            unless self.request.lg_spec
              self.request.lg_spec = podspec
            end
          elsif podspec_content
            path = download_params["path"]
            podspec_path = path + "/#{name}.podspec"
            begin
              File.open(podspec_path,"w+") do|f|
                f.write podspec_content
              end
            end
            if File.exist?(podspec_path)
              lg_spec = LgPodPlugin::PodSpec.form_file podspec_path
              if lg_spec
                self.request.lg_spec = lg_spec
                download_params["podspec_json"] = lg_spec.to_pretty_json
                download_params["source_files"] = lg_spec.source_files.keys
                download_params["prepare_command"] = lg_spec.prepare_command if lg_spec.prepare_command
                download_params.delete("podspec_content")
              else
                download_params["source_files"] = ["All"]
                download_params["prepare_command"] = nil
                download_params["podspec_json"] = podspec_content
                download_params.delete("podspec_content")
              end
            end
            FileUtils.rm_rf podspec_path
          end
          return download_params
        elsif File.exist?(download_params.to_s) && download_params
          FileUtils.chdir download_params
          LgPodPlugin::LCache.cache_pod(name, download_params.to_path, { :git => git }, podspec, self.request.released_pod) if self.request.single_git
          LgPodPlugin::LCache.cache_pod(name, download_params.to_path, self.request.get_cache_key_params,podspec, self.request.released_pod)
          FileUtils.chdir(LFileManager.download_director)
          FileUtils.rm_rf(download_params)
          self.request.checkout_options.delete(:branch) if commit
          self.request.checkout_options[:commit] = commit if commit
        end
        nil
      end

    end

    def pre_download_git_repository(checkout_options = {})
      lg_pod_path = LFileManager.cache_workspace(LProject.shared.workspace)
      lg_pod_path.mkdir(0700) unless lg_pod_path.exist?
      download_repository_strategy(lg_pod_path, checkout_options)
    end

    # 根据不同 git 源 选择下载策略
    def download_repository_strategy(path, checkout_options = {})
      FileUtils.chdir(path)
      git = checkout_options[:git]
      http = checkout_options[:http]
      if http
        begin
          checkout_options[:path] = path
          http_download = LgPodPlugin::HTTPDownloader.new(checkout_options)
          http_download.download
        rescue => exception
          LgPodPlugin.log_red "download_repository_strategy方法捕获到异常: #{exception}"
          nil
        end
      elsif git
        checkout_options[:path] = path
        checkout_options[:config] = self.request.config if self.request.config
        git_download = LgPodPlugin::GitDownloader.new(checkout_options)
        return git_download.download
      else
        nil
      end

    end

  end

end
