# require 'git'
require 'cocoapods/downloader'
require 'cocoapods/downloader/cache'
require 'cocoapods/downloader/response'
require 'cocoapods/downloader/request'

module LgPodPlugin

  class LCache

    def initialize
    end

    public

    def pod_cache_exist(name, options, spec = nil, released_pod = false)
      # 参数为空不执行下载任务, 交给 cocoapods 处理下载
      if options.nil?
        return [true, nil, nil]
      end
      destination, cache_pod_spec = self.find_pod_cache name, options, spec, released_pod
      lock_temp_file = destination.to_path + ".lock"
      if File.exist?(lock_temp_file)
        FileUtils.rm_rf lock_temp_file
      end
      if destination && destination.exist? && !destination.children.empty?
        return [true, destination, cache_pod_spec]
      else
        return [false, destination, cache_pod_spec]
      end
    end

    # 判断缓存是否存在且有效命中缓存

    public

    def find_pod_cache(name, options, spec = nil, released_pod = false)
      hash_map = Hash.new.merge!(options)
      if hash_map.has_key?(:version)
        hash_map.delete(:version)
      end
      request = LCache.create_download_request(name, hash_map, spec, released_pod)
      destination = LCache.path_for_pod(request)
      cache_pod_spec = LCache.path_for_spec(request)
      [destination, cache_pod_spec]
    end

    def self.root_path
      path = File.join(Dir.home, "Library/Caches/CocoaPods/Pods")
      Pathname(path)
    end

    def self.create_download_request(name, params, spec = nil, released_pod = false)
      if released_pod
        Pod::Downloader::Request.new(spec: spec, released: true, name: name, params: params)
      else
        Pod::Downloader::Request.new(spec: nil, released: false, name: name, params: params)
      end
    end

    def self.create_downloader_manager(request, target)
      result = Pod::Downloader::Response.new
      result.checkout_options = request.params
      result.location = target

      if request.released_pod?
        result.spec = request.spec
        podspecs = { request.name => request.spec }
      else
        podspecs = Pod::Sandbox::PodspecFinder.new(target).podspecs
        podspecs[request.name] = request.spec if request.spec
        podspecs.each do |name, spec|
          if request.name == name
            result.spec = spec
          end
        end
      end

      [result, podspecs]
    end

    def self.root_cache
      cache_path = LFileManager.cache_root_path
      return Pod::Downloader::Cache.new(cache_path)
    end

    # MARK - 缓存方法
    def self.path_for_pod(request, slug_opts = {})
      root_path + request.slug(**slug_opts)
    end

    def self.path_for_spec(request, slug_opts = {})
      path = root_path + 'Specs' + request.slug(**slug_opts)
      return Pathname.new(path.to_path + '.podspec.json')
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
        pods_pecs = Pod::Sandbox::PodspecFinder.new(target).podspecs
        pods_pecs[request.name] = request.spec if request.spec
        pods_pecs.each do |name, spec|
          if request.name == name
            result.spec = spec
            local_specs[request.name] = spec
          end
        end
      end
      [result, local_specs]
    end

    def self.copy_and_clean(source, destination, spec)
      return self.root_cache.copy_and_clean(source, destination, spec)
    end

    public

    def self.write_spec(spec, path)
      self.root_cache.write_spec(spec, path)
    end

    # 拷贝 pod 缓存文件到 sandbox

    public

    def self.cache_pod(name, target, options = {}, spec = nil, released_pod = false)
      checkout_options = Hash.new.deep_merge(options).reject do |key, val|
        !key || !val
      end
      request = create_download_request(name, checkout_options, spec, released_pod)
      result, pods_pecs = create_downloader_manager(request, target)
      pods_pecs.each do |name, s_spec|
        destination = path_for_pod request, { :name => name, :params => checkout_options }
        if !destination.exist? || destination.children.empty?
          LgPodPlugin.log_green "Copying #{name} from `#{target}` to `#{destination}` "
          copy_and_clean(target, destination, s_spec)
        end
        cache_pod_spec = path_for_spec(request, :name => name, :params => checkout_options)
        unless File.exist?(cache_pod_spec)
          write_spec(s_spec, cache_pod_spec)
        end
        if request.name == name
          result.location = destination
        end
      end

      result

    end

  end

end
