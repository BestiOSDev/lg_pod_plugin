require 'git'
require 'sqlite3'
require 'cocoapods-downloader'
require 'cocoapods-core/podfile/target_definition'

require "lg_pod_plugin/version"
require_relative 'lg_pod_plugin/log'
require_relative 'lg_pod_plugin/install'
require_relative 'lg_pod_plugin/request'
require_relative 'lg_pod_plugin/database'
require_relative 'lg_pod_plugin/download'
require_relative 'lg_pod_plugin/git_util'

module LgPodPlugin

  class Error < StandardError; end

  public
  # 对 Profile 方法进行拓展
  def pod(name, *requirements)
    Installer.new(self, name, requirements)
  end
end
