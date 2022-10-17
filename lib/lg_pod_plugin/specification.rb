require 'cocoapods'
require 'cocoapods-core'
require_relative 'l_util'
require_relative 'l_cache'
require_relative 'request'
require_relative 'install'

module  LgPodPlugin

  class Specification
    attr_accessor :spec
    attr_accessor :podfile
    attr_accessor :work_space
    attr_accessor :attributes_hash
    attr_accessor :dependencies
    def initialize(work_space, podfile, name = nil, version = nil)
      config = Pod::Config.instance
      sources_manager = config.send(:sources_manager)
      dependency = Pod::Dependency.new(name, version)
      set = sources_manager.search(dependency)
      self.podfile = podfile
      self.work_space = work_space
      self.spec = set.send(:specification)
      self.attributes_hash = self.spec.send(:attributes_hash)
      self.dependencies = self.attributes_hash["dependencies"]
    end

    def install
      pod_name = self.attributes_hash["name"]
      if pod_name.include?("/")
        real_name = pod_name.split("/").first
      else
        real_name = pod_name
      end
      if real_name == "lottie-ios"
        pp real_name
      end
      return if LRequest.shared.libs[real_name]
      pod_version = self.attributes_hash["version"]
      prepare_command = self.attributes_hash['prepare_command']
      return if prepare_command
      source = self.attributes_hash['source']
      return unless source.is_a?(Hash)
      git = source["git"] ||= ""
      tag = source["tag"] ||= ""
      return unless git.include?("https://github.com")
      requirements = {:git => git, :tag => tag, :spec => spec, :release_pod => true }
      LRequest.shared.checkout_options = requirements
      return unless LCache.new(self.work_space).find_pod_cache(real_name, {:git => git, :tag => tag})
      LRequest.shared.libs[real_name] = requirements
      LgPodPlugin::Installer.new(self.podfile, real_name, requirements)
    end

  end
end