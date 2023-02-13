require 'uri'
require 'resolv'

module LgPodPlugin

  class LURI
    public
    attr_reader :path
    attr_reader :host
    attr_reader :scheme
    attr_reader :hostname
    private
    attr_reader :uri
    public
    def initialize(git)
      begin
        uri = URI(git)
      rescue => exception
        if git.include?("git@") && git.include?(":")
          match = %r{(?<=git@).*?(?=:)}.match(git)
          host = match ? match[0] : ""
          base_url = LUtils.get_gitlab_base_url(git)
          path = base_url.split(":").last
          uri = URI("http://#{host}/#{path}")
        else
          LgPodPlugin.log_red exception
          uri = nil
        end
      end
      return unless uri
      if git.include?("ssh") || git.include?("git@gitlab") || git.include?("git@")
        redirect_url = get_redirect_url("https://#{uri.host}#{uri.path}")
        @uri = URI(redirect_url)
      else
        redirect_url = get_redirect_url("#{uri.scheme}://#{uri.host}#{uri.path}")
        @uri = URI(redirect_url)
      end
      @host = @uri.host ||= ""
      @path = @uri.path ||= ""
      @scheme = @uri.scheme ||= ""
      @hostname =  @scheme + "://" + @host
    end

    def get_redirect_url(host)
      redirect_url = Net::HTTP.get_response(URI(host))['location']
      begin
        uri = URI(redirect_url)
        return uri.scheme + "://" + uri.host
      rescue
        return host
      end
    end


    private
    #判断是否是 IP 地址
    # def is_address(host)
    #   match = %r{^((2[0-4]\d|25[0-5]|[01]?\d\d?)\.){3}(2[0-4]\d|25[0-5]|[01]?\d\d?)$}.match(host)
    #   !(match.nil?)
    # end

    # 获取 ip 地址
    # private
    # def getaddress(uri)
    #   begin
    #     if self.is_address(uri.host)
    #       ip = uri.host
    #       return ip
    #     else
    #       ip_address = Resolv.getaddress uri.host
    #       return ip_address
    #     end
    #   rescue
    #     result = %x(ping #{uri.host} -t 1)
    #     return if !result || result == "" || result.include?("timeout")
    #     match = %r{\d+.\d+.\d+.\d+}.match(result)
    #     return if match.nil?
    #     ip_address = match ? match[0] : ""
    #     begin
    #       return ip_address if IPAddr.new(ip_address)
    #     rescue => exception
    #       LgPodPlugin.log_red exception
    #       return nil
    #     end
    #   end
    # end

    public def to_s
      return "" unless @uri
      @uri.to_s
    end

  end


end
