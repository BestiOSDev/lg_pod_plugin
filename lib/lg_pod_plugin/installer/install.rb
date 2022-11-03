require 'pp'
require 'git'
require 'cgi'
require 'cocoapods'
require 'cocoapods-core'

module LgPodPlugin

  class LPodInstaller
    public
    attr_accessor :download_params
    private
    attr_accessor :downloader

    public
    def initialize
    end

    #安装 pod
    public
    def install(pod)
      hash = pod.checkout_options
      path = hash[:path]
      return nil if path
      @downloader = LDownloader.new(pod)
      @download_params = @downloader.pre_download_pod
      @download_params
    end

    def copy_file_to_caches
      request = @downloader.send(:request)
      name = request.send(:name)
      # if name == "LUnityFramework" || name == "LLogin" || name == "LCSOP" || name == "AFNetworking"
      #   pp name
      # end
      params = Hash.new.merge!(request.params)
      checkout_options = Hash.new.merge!(request.checkout_options)
      commit = checkout_options[:commit] ||= params[:commit]
      cache_podspec = request.spec
      unless cache_podspec
        cache_podspec = LProject.shared.cache_specs[name]
        request.spec = cache_podspec if cache_podspec
      end
      pod_is_exist = false
      if cache_podspec
        local_podspecs = Array.new
        destination_paths = self.download_params["destination_paths"] ||= []
        # cache_pod_spec_paths = self.download_params["cache_pod_spec_paths"] ||= []
        destination_paths.each_index do |idx|
          destination = destination_paths[idx]
          # cache_pod_spec_path = cache_pod_spec_paths[idx]
          if File.exist?(destination.to_path)
            pod_is_exist = true
            # attributes_hash = cache_podspec.send(:attributes_hash)
            # prepare_command = attributes_hash["prepare_command"] if attributes_hash
            # if prepare_command && !prepare_command.empty?
            #   LCache.clean_pod_unuse_files destination, cache_podspec
            # end
          end
        end
      else
        local_podspecs = Array.new
        destination_paths = self.download_params["destination_paths"] ||= []
        cache_pod_spec_paths = self.download_params["cache_pod_spec_paths"] ||= []
        destination_paths.each_index do |idx|
          destination = destination_paths[idx]
          pod_is_exist = File.exist?(destination)
          local_spec_path = destination.glob("#{name}.podspec").last
          if local_spec_path && File.exist?(local_spec_path)
            cache_podspec = Pod::Specification.from_file local_spec_path
            next unless cache_podspec
            LProject.shared.cache_specs[name] = cache_podspec
            LCache.write_spec cache_podspec, cache_pod_spec_paths[idx]
            # attributes_hash = cache_podspec.send(:attributes_hash)
            # prepare_command = attributes_hash["prepare_command"] if attributes_hash
            # if prepare_command && !prepare_command.empty?
              LCache.clean_pod_unuse_files destination, cache_podspec
            # end
          end
        end
        request.spec = cache_podspec
      end
      if pod_is_exist
        is_delete = request.params["is_delete"] ||= false
        LProject.shared.need_update_pods.delete(name) if is_delete
        request.checkout_options.delete(:branch) if commit
        request.checkout_options[:commit] = commit if commit
      else
        path = self.download_params["path"]
        return unless File.exist? path
        sandbox_path = Pathname(path)
        FileUtils.chdir sandbox_path
        # 需要重新下载文件
        git = checkout_options[:git]
        http = checkout_options[:http]
        tag = checkout_options[:tag]
        branch = checkout_options[:branch] ||= params[:branch]
        temp_zip_folder = self.downloader.select_git_repository_download_strategy sandbox_path, name, git, branch, tag, commit, false, http
        return unless temp_zip_folder&.exist?
        cache_key_params = request.get_cache_key_params
        LgPodPlugin::LCache.cache_pod(name, temp_zip_folder, { :git => git }, request.spec, request.released_pod) if request.single_git
        LgPodPlugin::LCache.cache_pod(name, temp_zip_folder, cache_key_params, request.spec, request.released_pod)
        FileUtils.chdir(LFileManager.download_director)
        FileUtils.rm_rf(sandbox_path)
        request.checkout_options.delete(:branch) if commit
        request.checkout_options[:commit] = commit if commit
      end

    end

  end
end
