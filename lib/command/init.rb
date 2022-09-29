require 'claide'
require_relative 'command'

module LgPodPlugin
  class Command
    class Init < Command
      self.command = "init"
      self.abstract_command = false
      self.summary = '初始化gitlab projects 信息'
      attr_accessor :username
      attr_accessor :password
      attr_accessor :host
      self.description = <<-DESC
        Manipulate the download cache for pods, like printing the cache content
        or cleaning the pods cache.
      DESC

      def initialize(argv)
        self.host = argv.option('host')
        self.username = argv.option('username')
        self.password = argv.option('password')
        super
      end

      def run
        raise unless self.host
        raise unless self.username
        raise unless self.password
        GitLab.request_gitlab_access_token(self.username, self .password, self.host)
      end

    end
  end
end
