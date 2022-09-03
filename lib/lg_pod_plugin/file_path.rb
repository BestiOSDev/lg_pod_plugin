
module LgPodPlugin

  class FileManager

    # 本地下载路径 ~Library/Caches/LgPodPlugin
    def self.download_director
      cache_path = File.join(Dir.home, "Library/Caches/LgPodPlugin")
      unless File::exist?(cache_path)
        # pp "文件路径不存在"
        Dir.mkdir(cache_path, 0700)
      end
      cache_path
    end

    def self.download_pod_path(name)
       path = download_director + "/#{name}"
       unless File::exist?(path) # pp "文件路径不存在"
         Dir.mkdir(path, 0700)
       end
       path
    end

  end

end