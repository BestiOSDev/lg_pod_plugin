require 'git'
require 'cocoapods-downloader'
require "lg_pod_plugin/version"
require_relative 'lg_pod_plugin/log'
require_relative 'lg_pod_plugin/install'
require_relative 'lg_pod_plugin/request'
require_relative 'lg_pod_plugin/database'
require_relative 'lg_pod_plugin/git_util'
require_relative 'lg_pod_plugin/downloader'
require 'cocoapods-core/podfile/target_definition'

module LgPodPlugin

  class Error < StandardError; end

  public
  # 对 Profile 方法进行拓展
  def pod(name, *requirements)
    Installer.new(self, name, requirements)
  end
end
