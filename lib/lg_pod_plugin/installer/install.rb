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
      self.download_params = @downloader.pre_download_pod
      return self.download_params
    end

    public
    def copy_file_to_caches
      request = @downloader.send(:request)
      name = request.send(:name)
      params = Hash.new.merge!(request.params)
      checkout_options = Hash.new.merge!(request.checkout_options)
      commit = checkout_options[:commit] ||= params[:commit]
      if request.lg_spec
        cache_podspec = request.lg_spec.spec
      else
        cache_podspec = nil
      end

      unless cache_podspec
        cache_podspec = LProject.shared.cache_specs[name]
        request.lg_spec = LgPodPlugin::PodSpec.form_pod_spec cache_podspec if cache_podspec
      end

      if cache_podspec
        destination = self.download_params["destination"]
        if destination && File.exist?(destination) && !Pathname(destination).children.empty?
          pod_is_exist = true
        else
          pod_is_exist = false
        end
      else
        destination = self.download_params["destination"]
        if destination && File.exist?(destination) && !Pathname(destination).children.empty?
          pod_is_exist = true
        else
          pod_is_exist = false
        end
        cache_pod_spec_path = self.download_params["cache_pod_spec_path"]
        local_spec_path = destination.glob("#{name}.podspec{,.json}").last
        if local_spec_path && File.exist?(local_spec_path)
          cache_podspec = Pod::Specification.from_file local_spec_path
          if cache_podspec
            LProject.shared.cache_specs[name] = cache_podspec
            LCache.write_spec cache_podspec, cache_pod_spec_path
            LCache.clean_pod_unused_files destination, cache_podspec
          end
        end
        request.lg_spec = LgPodPlugin::PodSpec.form_pod_spec cache_podspec if cache_podspec
      end
      if pod_is_exist
        is_delete = request.params["is_delete"] ||= false
        LProject.shared.need_update_pods.delete(name) if is_delete
        request.checkout_options.delete(:branch) if commit
        request.checkout_options[:commit] = commit if commit
      else
        git = checkout_options[:git]
        return unless git
        cache_podspec = request.lg_spec.spec if request.lg_spec
        branch = checkout_options[:branch]
        checkout_options[:name] = name if name
        unless branch
          branch = self.request.params[:branch] if request.params[:branch]
          checkout_options[:branch] = branch if branch
        end
        lg_pod_path = LFileManager.cache_workspace(LProject.shared.workspace)
        lg_pod_path.mkdir(0700) unless lg_pod_path.exist?
        checkout_options[:path] = lg_pod_path
        FileUtils.chdir lg_pod_path
        git_clone = GitRepository.new(checkout_options)
        download_params = git_clone.download
        return unless download_params && File.exist?(download_params)
        FileUtils.chdir download_params
        if request.single_git
          LgPodPlugin::LCache.cache_pod(name, download_params, { :git => git }, cache_podspec, request.released_pod)
        else
          LgPodPlugin::LCache.cache_pod(name, download_params, request.get_cache_key_params, cache_podspec, request.released_pod)
        end
        FileUtils.chdir(LFileManager.download_director)
        FileUtils.rm_rf(download_params)
        request.checkout_options.delete(:branch) if commit
        request.checkout_options[:commit] = commit if commit
      end

    end

  end
end
