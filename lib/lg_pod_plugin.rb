# require 'git'
require 'claide'
require 'cocoapods-downloader'
require "lg_pod_plugin/version"
require 'cocoapods-core/podfile/target_definition'

require_relative 'lg_pod_plugin/db/database'
require_relative 'lg_pod_plugin/utils/log'
require_relative 'lg_pod_plugin/config/target'
require_relative 'lg_pod_plugin/pod/external_pod'
require_relative 'lg_pod_plugin/pod/release-pod'
require_relative 'lg_pod_plugin/installer/project'
require_relative 'lg_pod_plugin/downloader/l_cache'
require_relative 'lg_pod_plugin/utils/file_path'
require_relative 'lg_pod_plugin/config/l_config'
require_relative 'lg_pod_plugin/installer/main'
require_relative 'lg_pod_plugin/installer/install'
require_relative 'lg_pod_plugin/downloader/request'
require_relative 'lg_pod_plugin/db/database'
require_relative 'lg_pod_plugin/net/l_uri'
require_relative 'lg_pod_plugin/utils/l_util'
require_relative 'lg_pod_plugin/git/gitlab_api'
require_relative 'lg_pod_plugin/net/net-ping'
require_relative 'lg_pod_plugin/git/gitlab_archive'
# require_relative 'lg_pod_plugin/config/lockfile_model'
require_relative 'lg_pod_plugin/downloader/downloader'
require_relative 'lg_pod_plugin/git/git_download'
require_relative 'lg_pod_plugin/git/git_clone'
require_relative 'lg_pod_plugin/downloader/overload_cache'

module LgPodPlugin
  autoload :Command, 'command/command'
  class Error < StandardError; end
end
