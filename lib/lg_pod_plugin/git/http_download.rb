require 'uri'
require_relative 'git_download'
require_relative '../uitils/l_util'
require_relative '../config/podspec'

module LgPodPlugin

  class HTTPDownloader

    private
    attr_reader :checkout_options
    public
    REQUIRED_ATTRS ||= %i[http name path lg_spec].freeze
    attr_accessor(*REQUIRED_ATTRS)
    def initialize(checkout_options = {})
      self.name = checkout_options[:name]
      self.path = checkout_options[:path]
      self.http = checkout_options[:http]
      self.lg_spec = checkout_options[:spec]
      @checkout_options = checkout_options
    end

    def download
      download_params = Hash.new
      new_filename = self.http.split("/").last ||= "lg_temp_pod.tar"
      download_params["path"] = self.path.to_path
      download_params["name"] = self.name
      download_params["type"] = "http"
      download_params["download_urls"] = [{ "filename" => (new_filename ? new_filename : filename), "url" => http }]
      if self.lg_spec
        download_params["podspec"] = self.lg_spec
        download_params["source_files"] = self.lg_spec.source_files.keys
      end
      return download_params
    end

    # def self.find_pod_director(root_path)
    #   temp_zip_folder = nil
    #   root_path.each_child do |f|
    #     ftype = File::ftype(f)
    #     next unless ftype == "directory"
    #     next if f.to_path.include?("__MACOSX")
    #     temp_zip_folder = f
    #     break
    #   end
    #   return temp_zip_folder
    # end

    def self.http_download_with(path, filename, http, async = true)
      if async

      else
        temp_file_path = LUtils.download_github_zip_file path, http, (new_filename ? new_filename : filename) , false
        return nil unless temp_file_path&.exist?
        contents = path.children
        entry = contents.last
        if entry && (entry.to_path.include?("tar") || entry.to_path.include?("tgz") || entry.to_path.include?("tbz") || entry.to_path.include?("txz"))
          raise "解压文件失败" unless LUtils.unzip_file entry.to_path, "./", true
          temp_zip_folder = path
        elsif entry && entry.to_path.include?(".zip")
          raise "解压文件失败" unless LUtils.unzip_file entry.to_path, "./", false
          FileUtils.rm_rf entry
          temp_zip_folder = self.find_pod_director path
          temp_zip_folder = path unless temp_zip_folder
        elsif entry && entry.directory?
          temp_zip_folder = self.find_pod_director(path)
          temp_zip_folder = path unless temp_zip_folder
        else
          temp_zip_folder = path
        end
        if temp_zip_folder&.exist?
          return temp_zip_folder
        else
          raise "下载文件失败"
        end
      end
    end

  end

end
