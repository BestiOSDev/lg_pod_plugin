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
        pod_version = %x(bundle exec pod --version).split("\n").first
        if version != pod_version
          version = pod_version
          version_file.open('w') { |f| f << version }
        end
      end

      def copy_and_clean(source, destination, spec)
        specs_by_platform = group_subspecs_by_platform(spec)
        destination.parent.mkpath
        Pod::Downloader::Cache.write_lock(destination) do
          if source && source.exist? && !source.children.empty?
            FileUtils.rm_rf(destination)
            FileUtils.cp_r(source, destination)
          end
          Pod::Installer::PodSourcePreparer.new(spec, destination).prepare!
          Pod::Sandbox::PodDirCleaner.new(destination, specs_by_platform).clean!
        end
      end

    end
  end
end
