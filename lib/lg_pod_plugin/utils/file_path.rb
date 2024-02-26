
module LgPodPlugin

  class LFileManager

    def self.cache_director
      Pathname(File.join(Dir.home, "Library/Caches"))
    end

    # 本地下载路径 ~Library/Caches/LgPodPlugin
    def self.download_director
      cache_path = self.cache_director.join("LgPodPlugin")
      # pp "文件路径不存在, 就创建"
      cache_path.mkdir(0700) unless cache_path.exist?
      cache_path
    end

    # pod缓存工作目录, 根据项目所在路径计算所得 确保唯一
    def self.cache_workspace(root)
      timestamp = "_#{Time.now.to_i}_"
      key = root.to_path + timestamp + "#{(rand * 10000000).to_i}"
      director = LUtils.md5(key)
      return self.download_director.join(director)
    end

    def self.cache_root_path
      cache_path = Pod::Config.instance.cache_root + 'Pods'
      cache_path
    end

  end

end