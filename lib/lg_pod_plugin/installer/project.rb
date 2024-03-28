require 'singleton'
require 'cocoapods'
require 'cocoapods-core'

module LgPodPlugin

  class LProject
    include Singleton

    attr_reader :podfile
    attr_reader :update
    attr_reader :targets
    attr_reader :workspace
    attr_reader :repo_update
    attr_reader :external_pods
    attr_accessor :cache_specs
    attr_accessor :refreshToken
    def setup(workspace,podfile_path, update, repo_update)
      @podfile = Pod::Podfile.from_file(podfile_path)
      @update = update
      @workspace = workspace
      @repo_update = repo_update
      target =  @podfile.send(:current_target_definition)
      children = target.children
      @targets = Array.new
      external_pods = Hash.new
      children.each do |s|
        target = LPodTarget.new(s)
        external_pods.merge!(target.dependencies)
        @targets.append(target)
      end
      @cache_specs = Hash.new
      @external_pods = Hash.new.merge!(external_pods)
      @refreshToken = nil
      return self
    end

    def self.shared
      return LProject.instance
    end

  end

end
