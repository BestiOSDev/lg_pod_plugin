# frozen_string_literal: true
require 'claide'
require_relative 'command'

module LgPodPlugin
  class Command
    class Doctor < Command
      self.abstract_command = false
      self.summary = 'Manipulate the CocoaPods cache'

      self.description = <<-DESC
        Manipulate the download cache for pods, like printing the cache content
        or cleaning the pods cache.
      DESC

      def initialize(argv)
        # pp argv
        super
      end

      def run
        pwd = Pathname.new(File.dirname(__FILE__)).realpath
        exexPath = pwd.parent.join("lg_pod_plugin/installer")
        FileUtils.chdir  exexPath
        pp  "sudo xattr -rd com.apple.quarantine ./PodDownload"
        result = %x(sudo xattr -rd com.apple.quarantine ./PodDownload)
      end

    end
  end
end
