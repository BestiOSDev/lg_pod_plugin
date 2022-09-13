require 'git'
require 'sqlite3'
require "lg_pod_plugin/version"
require_relative 'lg_pod_plugin/database'
require_relative 'lg_pod_plugin/download'
require_relative 'lg_pod_plugin/git_util'
require_relative 'lg_pod_plugin/pod_spec'
require_relative 'lg_pod_plugin/install'

module LgPodPlugin

  class Error < StandardError; end

  def self.install(defined_in_file = nil, profile, &block)
     Installer.new(defined_in_file, profile, &block)
  end

  def self.install_form_spec(profile, spec_path = nil)
    return Installer.new(profile).install_form_specs(spec_path)
  end

  autoload :Command, '../lib/command/command'
end

