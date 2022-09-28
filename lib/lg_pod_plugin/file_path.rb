
module LgPodPlugin

  class LFileManager

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
    def self.gitlab_accesstoken_path
      return self.download_director.join("gitlab_config.json")
    end
    # pod缓存工作目录, 根据项目所在路径计算所得 确保唯一
    def self.cache_workspace(root)
      timestamp = "_#{Time.now.to_i}_"
      key = root.to_path + timestamp + "#{(rand * 10000000).to_i}"
      director = Digest::MD5.hexdigest(key)
      return self.download_director.join(director)
    end

  end

end