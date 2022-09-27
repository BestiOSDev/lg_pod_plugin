require 'claide'
require_relative 'command'

module LgPodPlugin
  class Command
    class Init < Command
      self.command = "init"
      self.abstract_command = false
      self.summary = '初始化gitlab projects 信息'
      attr_accessor :token
      attr_accessor :group_id
      self.description = <<-DESC
        Manipulate the download cache for pods, like printing the cache content
        or cleaning the pods cache.
      DESC

      def initialize(argv)
        self.token = argv.option('token')
        self.group_id = argv.option('group_id')
        super
      end

      def run
        raise unless self.token
        GitLab.init_gitlab_projects(self.token, self.group_id)
      end

    end
  end
end
