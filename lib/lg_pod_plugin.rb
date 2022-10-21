require 'git'
require 'claide'
require 'cocoapods-downloader'
require "lg_pod_plugin/version"
require_relative 'lg_pod_plugin/log'
require_relative 'lg_pod_plugin/l_config'
require_relative 'lg_pod_plugin/runner'
require_relative 'lg_pod_plugin/install'
require_relative 'lg_pod_plugin/request'
require_relative 'lg_pod_plugin/database'
require_relative 'lg_pod_plugin/downloader'
require_relative 'lg_pod_plugin/gitlab_api'
require_relative 'lg_pod_plugin/gitlab_download'
require 'cocoapods-core/podfile/target_definition'

module LgPodPlugin
  autoload :Command, 'command/command'
  class Error < StandardError; end
end
