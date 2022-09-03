
require 'cocoapods/sandbox'
require 'cocoapods/downloader.rb'
require 'cocoapods/downloader/cache.rb'
require 'cocoapods/downloader/response.rb'
require 'cocoapods/downloader/request.rb'

module LgPodPlugin

class Cache

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

  def self.cache_pod(name, file_path, options = {})

    target = Pathname(file_path)
    request = download_request(name, options)
    result, podspecs = get_local_spec(request, target)
    result.location = nil

    podspecs.each do |name, spec|
      destination = path_for_pod(request, {})
      copy_and_clean(target, destination, spec)
      cache_pod_spec = path_for_spec(request, {})
      write_spec(spec, cache_pod_spec)
      if request.name == name
        result.location = destination
      end
    end



  end

end

end
