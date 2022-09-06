require 'git'
require 'cocoapods/sandbox'
require 'cocoapods/downloader.rb'
require 'cocoapods/downloader/cache.rb'
require 'cocoapods/downloader/response.rb'
require 'cocoapods/downloader/request.rb'

module LgPodPlugin

class Cache

  def initialize
    super
  end

  #判断缓存是否存在且有效命中缓存
  def find_pod_cache(name ,git, branch)
    ls = Git.ls_remote(git, :refs => true )
    branches = ls["branches"]
    last_commit = branches[branch][:sha]
    if last_commit == nil
      return
    end
    request = Cache.download_request(name, {:git => git, :commit => last_commit})
    destination = Cache.path_for_pod(request, {})
    cache_pod_spec = Cache.path_for_spec(request, {})
    if File.exist?(destination) && File.exist?(cache_pod_spec)
      true
    else
      false
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
    # result.checkout_options = download_source(target, request.params)
    result.location = target
    local_specs = nil
    if request.released_pod?
      result.spec = request.spec
      local_specs = { request.name => request.spec }
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
    Pod::Downloader::Cache.write_lock(destination) do
      FileUtils.rm_rf(destination)
      FileUtils.cp_r(source, destination)
      Pod::Installer::PodSourcePreparer.new(spec, destination).prepare!
      Pod::Sandbox::PodDirCleaner.new(destination, specs_by_platform).clean!
    end
  end

  def self.write_spec(spec, path)
    path.dirname.mkpath
    Pod::Downloader::Cache.write_lock(path) do
      path.open('w') { |f| f.write spec.to_pretty_json }
    end
  end

  def self.cache_pod(name, file_path, is_update, options = {})

    target = Pathname(file_path)
    request = download_request(name, options)
    result, pods_pecs = get_local_spec(request, target)
    result.location = nil
    pods_pecs.each do |s_name, s_spec|
      destination = path_for_pod(request, {})
      if !File.exist?(destination) || is_update
        copy_and_clean(target, destination, s_spec)
      end
      cache_pod_spec = path_for_spec(request, {})
      if !File.exist?(cache_pod_spec) || is_update
        write_spec(s_spec, cache_pod_spec)
      end
      if request.name == s_name
        result.location = destination
      end
    end

  end

end

end
