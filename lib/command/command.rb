require 'claide'

module LgPodPlugin
  class Command < CLAide::Command
    require_relative './cache'

    self.abstract_command = true
    self.command = 'pod'
    self.version = VERSION
    self.description = 'this is my command lint tool!'
    self.plugin_prefixes = %w(claide cocoapods)

    def self.options
      [
        ['--allow-root', 'Allows CocoaPods to run as root'],
        ['--silent', 'Show nothing'],
      ].concat(super)
    end

    def self.run(argv)
      super(argv)
    end

    def initialize(argv)
      super
      # config.silent = argv.flag?('silent', config.silent)
      # config.allow_root = argv.flag?('allow-root', config.allow_root)
      # config.verbose = self.verbose? unless verbose.nil?
      unless self.ansi_output?
        Colored2.disable!
        String.send(:define_method, :colorize) { |string, _| string }
      end
    end
  end
end