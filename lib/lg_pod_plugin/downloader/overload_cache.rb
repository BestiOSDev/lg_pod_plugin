require 'fileutils'
require 'tmpdir'

module Pod
  module Downloader
    # The class responsible for managing Pod downloads, transparently caching
    # them in a cache directory.
    #
    class Cache


      private
      # Ensures the cache on disk was created with the same CocoaPods version as
      # is currently running.
      #
      # @return [Void]
      #
      def ensure_matching_version
        version_file = root + 'VERSION'
        if version_file.file?
          version = version_file.read.strip
        else
          version = Pod::VERSION
        end
        version_file.open('w') { |f| f << Pod::VERSION }
      end

    end
  end
end
