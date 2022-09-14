require 'git'
require 'sqlite3'
require "lg_pod_plugin/version"
require 'cocoapods/user_interface'
require_relative 'lg_pod_plugin/database'
require_relative 'lg_pod_plugin/download'
require_relative 'lg_pod_plugin/git_util'
require_relative 'lg_pod_plugin/pod_spec'
require_relative 'lg_pod_plugin/install'
require 'cocoapods-core/podfile/target_definition'

module LgPodPlugin

  class String
    # colorization
    def colorize(color_code)
      "\e[#{color_code}m#{self}\e[0m"
    end

    def red
      colorize(31)
    end

    def green
      colorize(32)
    end

    def yellow
      colorize(33)
    end

    def blue
      colorize(34)
    end

    def pink
      colorize(35)
    end

    def light_blue
      colorize(36)
    end
  end

  class Error < StandardError; end

  def self.log_red(msg)
    Pod::CoreUI.puts msg.red
  end

  def self.log_blue(msg)
    Pod::CoreUI.puts msg.blue
  end

  def self.log_green(msg)
    Pod::CoreUI.puts msg.green
  end

  def self.log(msg)
    Pod::CoreUI.puts msg
  end

  # 对 Profile 方法进行拓展
  def pod(name, *requirements)
    Installer.new(self, name, requirements)
  end

end

