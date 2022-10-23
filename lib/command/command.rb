require 'claide'

module LgPodPlugin
  class Command < CLAide::Command
    require_relative 'cache'
    require_relative 'update'
    require_relative 'init'
    require_relative 'install'
    self.command = 'lg'
    self.version = VERSION
    self.abstract_command = true
    self.description = 'this is `lg_pod_plugin` command line tool!'
    def self.options
      [
        ['--silent', 'Show nothing']
      ].concat(super)
    end

    def self.run(argv)
      super(argv)
    end

    def initialize(argv)
      super
    end

  end
end
