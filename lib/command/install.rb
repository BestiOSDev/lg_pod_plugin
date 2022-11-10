require 'claide'

module LgPodPlugin
  class Command
    class Install < Command
      REQUIRED_ATTRS ||= %i[log repo_update].freeze
      attr_accessor(*REQUIRED_ATTRS)

      self.summary = 'Install project dependencies according to versions from a Podfile.lock'

      self.description = <<-DESC
        Downloads all dependencies defined in `Podfile` and creates an Xcode
        Pods library project in `./Pods`.

        The Xcode project file should be specified in your `Podfile` like this:

            project 'path/to/XcodeProject.xcodeproj'

        If no project is specified, then a search for an Xcode project will
        be made. If more than one Xcode project is found, the command will
        raise an error.

        This will configure the project to reference the Pods static library,
        add a build configuration file, and add a post build script to copy
        Pod resources.

        This may return one of several error codes if it encounters problems.
        * `1` Generic error code
        * `31` Spec not found (i.e out-of-date source repos, mistyped Pod name etc...)
      DESC

      def self.options
        [
          ['--repo-update', 'Force running `pod repo update` before install'],
          ['--deployment', 'Disallow any changes to the Podfile or the Podfile.lock during installation'],
          ['--clean-install', 'Ignore the contents of the project cache and force a full pod installation. This only ' \
            'applies to projects that have enabled incremental installation'],
        ].concat(super).reject { |(name, _)| name == '--no-repo-update' }
      end

      def initialize(argv)
        self.log = argv.flag?('verbose')
        self.repo_update = argv.flag?('repo-update')
        super
      end

      def run

        begin_time = Time.now.to_i
        LgPodPlugin::Main.run("install", { :verbose => self.log, :repo_update => self.repo_update })
        end_time = Time.now.to_i
        LgPodPlugin.log_blue "`lg install`安装所需时间: #{end_time - begin_time}"
      end

    end
  end
end
