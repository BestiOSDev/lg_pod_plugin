require 'git'
require 'sqlite3'
require "lg_pod_plugin/version"
require_relative 'lg_pod_plugin/database'
require_relative 'lg_pod_plugin/download'
require_relative 'lg_pod_plugin/git_util'
require_relative 'lg_pod_plugin/pod_spec'
require_relative 'lg_pod_plugin/install'
require 'cocoapods-core/podfile/target_definition'

module LgPodPlugin

  class Error < StandardError; end
  # 在已经存在target下边安装pod
  def self.install(defined_in_file = nil, profile, &block)
     target = profile.send(:current_target_definition)
     Installer.new(defined_in_file, target, &block)
  end

  # 通过spec文件安装
  def self.install_form_spec(profile, spec_path = nil)
    target = profile.send(:current_target_definition)
    return Installer.new(target).install_form_specs(spec_path)
  end

  # 创建一个 target, 并在这个 target 下安装
  def self.target(defined_in_file = nil, name, &block)
    definition = Pod::Podfile::TargetDefinition.new(name, nil)
    return Installer.new(definition, &block)
  end

  # autoload :Command, '../lib/command/command'
end

