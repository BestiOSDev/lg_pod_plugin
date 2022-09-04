require "lg_pod_plugin/version"
require_relative 'lg_pod_plugin/git_info'
require_relative 'lg_pod_plugin/pod_spec'
require_relative 'lg_pod_plugin/install'

module LgPodPlugin

  class Error < StandardError; end

  def self.install(defined_in_file = nil, target, &block)
     Installer.new(defined_in_file, target, &block)
  end

  def self.install_form_spec(target, spec_path = nil)
    return Installer.new(target).install_form_specs(spec_path)
  end

end

