require 'claide'

module LgPodPlugin
  class Cache < Command
    self.abstract_command = true
    self.summary = 'Inter-process communication'
    def initialize(argv)

    end
    def output_pipe
      pp "hello world"
    end

    def run
      pp "run"
    end
  end
end