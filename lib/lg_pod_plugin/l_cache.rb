require 'git'
require 'cocoapods/downloader'
require 'cocoapods/downloader/cache'
require 'cocoapods/downloader/response'
require 'cocoapods/downloader/request'

module LgPodPlugin

  class LCachePodInfo
    REQUIRED_ATTRS ||= %i[sha tag name path branch timestamp].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize
      super
    end

  end

  class LCache
    REQUIRED_ATTRS ||= %i[workspace cache_root].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(workspace)
      self.workspace = workspace
      self.cache_root = LFileManager.cache_workspace(self.workspace)
    end
    
    #根据git branch commit 返回请求参数用来获取缓存 path
    def get_request_params(name, git, branch, tag, commit)
      options = { :git => git }
      if git && tag
        options[:tag] = tag
        options[:commit] = commit
      elsif git && branch
        if commit
          options[:commit] = commit
        else
          new_commit_id = LGitUtil.git_ls_remote_refs(git, branch, nil, commit)
          options[:commit] = new_commit_id
        end
      elsif git && commit
        options[:commit] = commit
      end
      return options
    end
    #判断缓存是否存在且有效命中缓存
    def find_pod_cache(name, git, branch, tag, commit, is_update)
      hash_map = nil 
      if is_update
        hash_map = self.get_request_params(name, git, branch, tag, commit)
      else 
        if LRequest.shared.lock_params
          lock_tag = LRequest.shared.lock_params[:tag]
          lock_branch = LRequest.shared.lock_params[:branch]
          lock_commit = LRequest.shared.lock_params[:commit]
          hash_map = self.get_request_params(name, git, lock_branch, lock_tag, lock_commit)
        else
          hash_map = self.get_request_params(name, git, branch, tag, commit)
        end
      end
      request = LCache.download_request(name, hash_map)
      destination = LCache.path_for_pod(request, {})
      cache_pod_spec = LCache.path_for_spec(request, {})
      if File.exist?(destination) && File.exist?(cache_pod_spec)
        return false
      else
        return true
      end
    end

    def self.root_path
      path = File.join(Dir.home, "Library/Caches/CocoaPods/Pods")
      Pathname(path)
    end

    def self.download_request(name, params)
      Pod::Downloader::Request.new(spec: nil, released: false, name: name, params: params)
    end

    def self.path_for_pod(request, slug_opts = {})
      root = self.root_path
      root + request.slug(**slug_opts)
    end

    def self.path_for_spec(request, slug_opts = {})
      root = self.root_path
      path = root + 'Specs' + request.slug(**slug_opts)
      Pathname.new(path.to_path + '.podspec.json')
    end

    def self.cached_spec(request)
      path = path_for_spec(request)
      path.file? && Specification.from_file(path)
    rescue JSON::ParserError
      nil
    end

    def self.get_local_spec(request, target)
      result = Pod::Downloader::Response.new
      result.location = target
      if request.released_pod?
        result.spec = request.spec
        local_specs = { request.name => request.spec }
        return [request, local_specs]
      else
        local_specs = {}
        podspecs = Pod::Sandbox::PodspecFinder.new(target).podspecs
        podspecs[request.name] = request.spec if request.spec
        podspecs.each do |name, spec|
          if request.name == name
            result.spec = spec
            local_specs[request.name] = spec
          end
        end
      end

      [result, local_specs]
    end

    def self.group_sub_specs_by_platform(spec)
      specs_by_platform = {}
      [spec, *spec.recursive_subspecs].each do |ss|
        ss.available_platforms.each do |platform|
          specs_by_platform[platform] ||= []
          specs_by_platform[platform] << ss
        end
      end
      specs_by_platform
    end

    def self.copy_and_clean(source, destination, spec)
      specs_by_platform = group_sub_specs_by_platform(spec)
      destination.parent.mkpath
      self.write_lock(destination) do
        FileUtils.rm_rf(destination)
        FileUtils.cp_r(source, destination)
        Pod::Installer::PodSourcePreparer.new(spec, destination).prepare!
        Pod::Sandbox::PodDirCleaner.new(destination, specs_by_platform).clean!
      end
    end

    def self.write_lock(location, &block)
      self.lock(location, File::LOCK_EX, &block)
    end

    def self.lock(location, lock_type)
      raise ArgumentError, 'no block given' unless block_given?
      lockfile = "#{location}.lock"
      f = nil
      loop do
        f.close if f
        f = File.open(lockfile, File::CREAT, 0o644)
        f.flock(lock_type)
        break if self.valid_lock?(f, lockfile)
      end
      begin
        yield location
      ensure
        if lock_type == File::LOCK_SH
          f.flock(File::LOCK_EX)
          File.delete(lockfile) if self.valid_lock?(f, lockfile)
        else
          File.delete(lockfile)
        end
        f.close
      end
    end

    def self.valid_lock?(file, filename)
      file.stat.ino == File.stat(filename).ino
    rescue Errno::ENOENT
      false
    end

    def self.write_spec(spec, path)
      path.dirname.mkpath
      Pod::Downloader::Cache.write_lock(path) do
        path.open('w') { |f| f.write spec.to_pretty_json }
      end
    end

    # 拷贝 pod 缓存文件到 sandbox
    def self.cache_pod(name, target, options = {})
      request = LCache.download_request(name, options)
      result, pods_pecs = get_local_spec(request, target)
      result.location = nil
      pods_pecs.each do |s_name, s_spec|
        destination = path_for_pod(request, {})
        if !File.exist?(destination)
          LgPodPlugin.log_green "Copying #{name} from `#{target}` to `#{destination}` "
          copy_and_clean(target, destination, s_spec)
        end
        cache_pod_spec = path_for_spec(request, {})
        if !File.exist?(cache_pod_spec)
          write_spec(s_spec, cache_pod_spec)
        end
        if request.name == s_name
          result.location = destination
        end

      end

    end

    # 根据下载参数生产缓存的路径
    def get_download_path(name)
      # hash_map = {:git => git}
      # if git && tag
      #   hash_map[:tag] = tag
      # elsif git && commit
      #   hash_map[:commit] = commit
      # elsif git && branch
      #   hash_map[:commit] = commit
      # end
      # request = LCache.download_request(name, hash_map)
      # self.slug(name, request.params, nil)
        self.cache_root.join(name)
    end

    # 根据下载参数生产缓存目录
    def slug(name, params, spec)
      path = ""
      checksum = spec&.checksum && '-' << spec.checksum[0, 5]
      opts = params.to_a.sort_by(&:first).map { |k, v| "#{k}=#{v}" }.join('-')
      digest = Digest::MD5.hexdigest(opts)
      if digest
        path += "#{digest}"
      end
      if checksum
        path += "#{checksum}"
      end
      path
    end

  end

end
