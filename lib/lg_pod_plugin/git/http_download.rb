module LgPodPlugin

  class HTTPDownloader

    def self.find_pod_director(root_path)
      temp_zip_folder = nil
      root_path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        next if f.to_path.include?("__MACOSX")
        temp_zip_folder = f
        break
      end
      return temp_zip_folder
    end

    def self.http_download_with(path, filename, http, async = true)
      new_filename = http.split("/").last
      if async
        return { "path" => path.to_path, "filename" => (new_filename ? new_filename : filename), "url" => http }
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
        elsif entry.directory?
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
