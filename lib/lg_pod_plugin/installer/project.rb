require 'singleton'
require 'cocoapods'
require 'cocoapods-core'

module LgPodPlugin

  class LProject
    include Singleton

    attr_reader :podfile
    attr_reader :lockfile
    attr_reader :update
    attr_reader :targets
    attr_reader :workspace
    attr_reader :repo_update
    attr_reader :external_pods
    attr_reader :need_update_pods
    def setup(workspace,podfile_path, update, repo_update)
      @podfile = Pod::Podfile.from_file(podfile_path)
      @update = update
      @workspace = workspace
      @repo_update = repo_update
      lockfile_path = workspace.join("Podfile.lock")
      @lockfile = Pod::Lockfile.from_file(lockfile_path) if lockfile_path.exist?
      target =  @podfile.send(:current_target_definition)
      children = target.children
      @targets = Array.new
      external_pods = Hash.new
      children.each do |s|
        target = LPodTarget.new(s)
        external_pods.merge!(target.dependencies)
        @targets.append(target)
      end
      @external_pods = Hash.new.merge!(external_pods)
      @need_update_pods = Hash.new.merge!(external_pods)
      return self
    end

    def self.shared
      return LProject.instance
    end

  end

end
