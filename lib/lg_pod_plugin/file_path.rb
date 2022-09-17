
module LgPodPlugin

  class FileManager

    def self.cache_director
      Pathname(File.join(Dir.home, "Library/Caches"))
    end

    # 本地下载路径 ~Library/Caches/LgPodPlugin
    def self.download_director
      cache_path = self.cache_director.join("LgPodPlugin")
      unless cache_path.exist?
        # pp "文件路径不存在"
        cache_path.mkdir(0700)
      end
      cache_path
    end

    def self.cache_pod_path(name)
      download_director.join(name)
    end

    #生产临时缓存文件目录
    def self.temp_download_path(root)
      timestamp = "_#{Time.now.to_i}_"
      key = root.to_path + timestamp + "#{(rand() * 10000000).to_i}"
      director = Digest::MD5.hexdigest(key)
      return self.download_director.join(director)
    end

  end

end