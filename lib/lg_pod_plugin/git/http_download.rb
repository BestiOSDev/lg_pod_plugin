require 'uri'
require_relative 'git_download'
require_relative '../utils/l_util'
require_relative '../config/podspec'

module LgPodPlugin

  class HTTPDownloader

    private
    attr_reader :checkout_options
    public
    REQUIRED_ATTRS ||= %i[http name path].freeze
    attr_accessor(*REQUIRED_ATTRS)
    def initialize(checkout_options = {})
      self.name = checkout_options[:name]
      self.path = checkout_options[:path]
      self.http = checkout_options[:http]
      @checkout_options = checkout_options
    end

    def download
      download_params = Hash.new
      new_filename = self.http.split("/").last ||= "lg_temp_pod.tar"
      download_params["path"] = self.path.to_path
      download_params["name"] = self.name
      download_params["type"] = "http"
      download_params["filename"] = (new_filename ? new_filename : filename)
      download_params["url"] = http
      download_params
    end

  end

end
