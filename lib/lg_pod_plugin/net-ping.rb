require 'uri'
require 'resolv'
require "ipaddr"
require_relative 'l_util'

module LgPodPlugin

  class Ping
    attr_accessor :uri
    attr_accessor :ip
    attr_accessor :network_ok
    def initialize(url)
      self.uri = LUtils.git_to_uri(url)
    end

    def ping
      return false unless self.uri
      result = %x(ping #{uri.host} -t 1)
      if result.include?("timeout")
        return false
      end
      if result && result.include?("(") && result.include?("):")
        ip_address = result.split("(").last.split(")").first
        begin
          if IPAddr.new ip_address
            self.ip = ip_address
            return  true
          else
            return false
          end
        rescue
          return false
        end
      else
        return false
      end
    end

  end

end