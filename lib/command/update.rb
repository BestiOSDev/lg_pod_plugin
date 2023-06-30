require 'claide'
module LgPodPlugin
  class Command
    class Update < Command
      REQUIRED_ATTRS ||= %i[log repo_update clean_install].freeze
      attr_accessor(*REQUIRED_ATTRS)
      self.summary = 'Update outdated project dependencies and create new ' \
        'Podfile.lock'

      self.description = <<-DESC
        Updates the Pods identified by the specified `POD_NAMES`, which is a
        space-delimited list of pod names. If no `POD_NAMES` are specified, it
        updates all the Pods, ignoring the contents of the Podfile.lock. This
        command is reserved for the update of dependencies; pod install should
        be used to install changes to the Podfile.
      DESC

      def self.options
        [
          ["--sources=#{Pod::TrunkSource::TRUNK_REPO_URL}", 'The sources from which to update dependent pods. ' \
           'Multiple sources must be comma-delimited'],
          ['--exclude-pods=podName', 'Pods to exclude during update. Multiple pods must be comma-delimited'],
          ['--clean-install', 'Ignore the contents of the project cache and force a full pod installation. This only ' \
           'applies to projects that have enabled incremental installation'],
        ].concat(super)
      end

      def initialize(argv)
        self.log = argv.flag?('verbose')
        repo_flag = argv.flag?('repo-update')
        if repo_flag.nil?
          self.repo_update = false
        else
          self.repo_update = repo_flag
        end
        if argv.flag?('clean-install').nil?
          @clean_install = false
        else
          @clean_install = true
        end
        super
      end

      def run
        begin_time = Time.now.to_i
        LgPodPlugin::Main.run("update", { :verbose => self.log, :repo_update => self.repo_update, :clean_install => self.clean_install })
        end_time = Time.now.to_i
        LgPodPlugin.log_blue "`lg update`安装所需时间: #{end_time - begin_time}"
      end
    end
  end
end
