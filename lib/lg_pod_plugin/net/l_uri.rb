require 'uri'
require 'resolv'

module LgPodPlugin

  class LURI
    public
    # attr_reader :path
    attr_reader :host
    attr_reader :scheme
    attr_reader :hostname
    private
    attr_reader :uri
    public
    def initialize(git)
      if git.include?("git@") && git.include?(":")
        match = %r{(?<=git@).*?(?=:)}.match(git)
        host = match ? match[0] : ""
        if is_address(host)
          base_url = LUtils.get_gitlab_base_url(git)
          path = base_url.split(":").last
          origin_uri = URI("http://#{host}/#{path}")
        else
          base_url = LUtils.get_gitlab_base_url(git)
          path = base_url.split(":").last
          origin_uri = URI("https://#{host}/#{path}")
        end
      else
        origin_uri = URI(git)
      end
      return if origin_uri.nil?
      @uri = origin_uri
      @host = @uri.host
      @scheme = @uri.scheme ||= "https"
      @hostname =  @scheme + "://" + @host
    end

    private
    #判断是否是 IP 地址
    def is_address(host)
      match = %r{^((2[0-4]\d|25[0-5]|[01]?\d\d?)\.){3}(2[0-4]\d|25[0-5]|[01]?\d\d?)$}.match(host)
      !(match.nil?)
    end
    
    public def to_s
      return "" unless @uri
      @uri.to_s
    end

  end


end
