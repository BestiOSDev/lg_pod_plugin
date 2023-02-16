require 'cocoapods'
require 'cocoapods-core'
require_relative '../installer/concurrency'

module LgPodPlugin

  class Main

    #删除旧的换成目录
    def self.clean_sandbox
      sand_box = LFileManager.download_director
      sand_box.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        next if f.to_path.include?("database")
        FileUtils.rm_rf f.to_path
      end
    end

    public
    def self.run(command, options = {})
      clean_sandbox()
      workspace = Pathname(Dir.pwd)
      update = (command == "update")
      LSqliteDb.shared.init_database
      repo_update = options[:repo_update] ||= false
      LgPodPlugin.log_blue "当前工作目录 #{workspace}"
      podfile_path = check_podfile_exist?(workspace)
      return unless podfile_path
      project = LProject.shared.setup(workspace, podfile_path, update, repo_update)
      self.install_external_pod(project)
      # # 安装开发版本pod
      verbose = options[:verbose] ||= false
      clean_install = options[:clean_install] ||= false
      ReleasePod.install_release_pod(update, repo_update, verbose, clean_install)
    end

    def self.install_external_pod(project)
      #下载 External pods
      LgPodPlugin.log_blue "Pre-downloading External Pods" unless project.targets.empty?
      all_installers = Hash.new
      project.targets.each do |target|
        target.dependencies.each do |_, pod|
          installer = LPodInstaller.new
          download_params = installer.install(pod)
          if download_params
            all_installers[download_params["name"]] = installer
          end
        end
      end
      # 通过 swift 可执行文件进行异步下载任务
      LgPodPlugin::Concurrency.async_download_pods(all_installers.values)
    end

    def self.check_podfile_exist?(workspace)
      podfile_path = workspace.join("Podfile")
      return podfile_path if podfile_path.exist?
      podfile_path = workspace.join("Podfile.rb")
      return podfile_path if podfile_path.exist?
      raise Informative, "No `Podfile' found in the project directory."
    end

  end
end
