
module LgPodPlugin
  #git 仓库信息
  class GitRepositoryInfo
    def get_temp_folder
      @temp_folder
    end

    def get_name
      @name
    end

    def get_log
      @log
    end

    def set_log(value)
      @log = value
    end

    def get_pod_path
      @pod_path
    end

    def set_pod_path(value)
      @pod_path = value
    end

    def initialize(name, temp_folder)
      @name = name
      @temp_folder = temp_folder
    end
  end

end