
module LgPodPlugin

  class FileManager

    def self.cache_director
      Pathname(File.join(Dir.home, "Library/Caches"))
    end

    # 本地下载路径 ~Library/Caches/LgPodPlugin
    def self.download_director
      cache_path =  self.cache_director.join("LgPodPlugin")
      unless cache_path.exist?
        # pp "文件路径不存在"
        cache_path.mkdir(0700)
      end
      cache_path
    end

    def self.download_pod_path(name)
      download_director.join(name)
    end

  end

end