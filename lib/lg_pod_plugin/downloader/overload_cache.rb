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

      public
      def copy_and_clean(source, destination, spec)
        attributes_hash = spec.send(:attributes_hash) || {}
        name = attributes_hash["name"] ||= ""
        specs_by_platform = group_subspecs_by_platform(spec)
        destination.parent.mkpath
        Pod::Downloader::Cache.write_lock(destination) do
          if source && source.exist? && !source.children.empty?
            FileUtils.rm_rf(destination)
            FileUtils.cp_r(source, destination)
          end
          LgPodPlugin.log_green "-> Copy #{name} from #{source} to #{destination}"
          Pod::Installer::PodSourcePreparer.new(spec, destination).prepare!
          Pod::Sandbox::PodDirCleaner.new(destination, specs_by_platform).clean!
        end
      end

      public
      def write_spec(spec, path)
        path.dirname.mkpath
        Pod::Downloader::Cache.write_lock(path) do
          path.open('w') { |f| f.write spec.to_pretty_json }
        end
      end

    end
  end
end
