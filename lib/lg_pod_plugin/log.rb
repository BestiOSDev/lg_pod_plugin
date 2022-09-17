
require_relative 'string'
require 'cocoapods/user_interface'

module LgPodPlugin

  def self.log_red(msg)
    Pod::CoreUI.puts msg.red
  end

  def self.log_blue(msg)
    Pod::CoreUI.puts msg.blue
  end

  def self.log_green(msg)
    Pod::CoreUI.puts msg.green
  end

  def self.log_yellow(msg)
    Pod::CoreUI.puts msg.yellow
  end

  def self.log(msg)
    Pod::CoreUI.puts msg
  end
end
