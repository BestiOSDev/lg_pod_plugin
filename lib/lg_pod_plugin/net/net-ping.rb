require 'uri'
require 'resolv'
require "ipaddr"

module LgPodPlugin

  class Ping
    attr_accessor :ip
    attr_accessor :network_ok
    attr_accessor :uri
    def initialize(url)
      uri = LURI.new(url)
      if uri.host
        self.uri = uri
        self.ip = uri.ip
        self.network_ok = true
      else
        self.uri = nil
        self.ip = nil
        self.network_ok = false
      end
    end


  end

end
