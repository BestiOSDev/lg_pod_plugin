require 'pp'
require 'git'
require 'cgi'
require 'cocoapods'
require 'cocoapods-core/podfile'
require 'cocoapods-core/podfile/target_definition'

module LgPodPlugin

  class Installer
    private
    attr_accessor :downloader

    public
    def initialize
    end

    #安装 pod
    public
    def install(pod)
      hash = pod.checkout_options
      path = hash[:path]
      return nil if path
      download = LDownloader.new(pod)
      download.pre_download_pod
    end
  end
end
