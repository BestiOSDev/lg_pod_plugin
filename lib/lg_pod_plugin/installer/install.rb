require 'pp'
require 'git'
require 'cgi'
require 'cocoapods'
require 'cocoapods-core/podfile'
require 'cocoapods-core/podfile/target_definition'

module LgPodPlugin

  class LPodInstaller
    private
    attr_accessor :downloader
    attr_accessor :download_params

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

    def find_pod_director(root_path, project_name, type, branch, tag, commit)
      temp_zip_folder = nil
      root_path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        if type == "github-tag"
          if f.to_path.include?("#{tag}") || f.to_path.include?("#{project_name}")
            temp_zip_folder = f
            break
          end
        elsif type == "github-branch"
          if f.to_path.include?("#{branch}") || f.to_path.include?("#{project_name}")
            temp_zip_folder = f
            break
          end
        elsif type == "github-commit"
          if f.to_path.include?("#{commit}") || f.to_path.include?("#{project_name}")
            temp_zip_folder = f
            break
          end
        elsif type == "gitlab-branch"
          if f.to_path.include?("#{branch}") || f.to_path.include?("#{project_name}")
            temp_zip_folder = f
            break
          end
        elsif type == "gitlab-commit"
          if f.to_path.include?("#{commit}") || f.to_path.include?("#{project_name}")
            temp_zip_folder = f
            break
          end
        elsif type == "gitlab-tag"
          if f.to_path.include?("#{tag}") || f.to_path.include?("#{project_name}")
            temp_zip_folder = f
            break
          end
        else
          if !project_name.empty? && f.to_path.include?("#{project_name}")
            temp_zip_folder = f
            break
          end
        end
      end
      return temp_zip_folder ? temp_zip_folder : root_path
    end
    public
    def copy_file_to_caches
      temp_zip_folder = nil
      path = self.download_params["path"]
      return unless File.exist? path
      type = self.download_params["type"]
      sandbox_path = Pathname(path)
      FileUtils.chdir sandbox_path
      request = @downloader.send(:request)
      params = Hash.new.merge!(request.params)
      checkout_options = Hash.new.merge!(request.checkout_options)
      name = request.send(:name)
      git = checkout_options[:git]
      http = checkout_options[:http]
      tag = checkout_options[:tag]
      if tag
        new_tag = (tag.include?("v") ? tag.split("v").last : tag)
      else
        new_tag = tag
      end
      commit = checkout_options[:commit] ||= params[:commit]
      branch = checkout_options[:branch] ||= params[:branch]
      if git
        project_name = LUtils.get_git_project_name git
      else
        project_name = ""
      end
      temp_zip_folder = nil
      contents = sandbox_path.children
      entry = contents.last
      if entry && (entry.to_path.include?("tar") || entry.to_path.include?("tgz") || entry.to_path.include?("tbz") || entry.to_path.include?("txz"))
        result = LUtils.unzip_file entry.to_path, "./", true
        temp_zip_folder = sandbox_path if result
      elsif entry.directory?
        temp_zip_folder = self.find_pod_director(sandbox_path, project_name, type, branch, new_tag, commit)
      else
        temp_zip_folder = sandbox_path
      end
      unless temp_zip_folder&.exist?
        sandbox_path.children.each do |f|
          FileUtils.rm_rf f
        end
        temp_zip_folder = self.downloader.select_git_repository_download_strategy sandbox_path, name, git, branch, tag, commit, false, http
        return unless temp_zip_folder&.exist?
      end
      LgPodPlugin::LCache.cache_pod(name, temp_zip_folder, { :git => git }, request.spec, request.released_pod) if request.single_git
      LgPodPlugin::LCache.cache_pod(name, temp_zip_folder, request.get_cache_key_params, request.spec, request.released_pod)
      FileUtils.chdir(LFileManager.download_director)
      FileUtils.rm_rf(sandbox_path)
      request.checkout_options.delete(:branch) if commit
      request.checkout_options[:commit] = commit if commit
    end

  end
end
