require 'cocoapods'
require 'cocoapods-core'

module LgPodPlugin

  class Main
    public
    def self.run(command, options = {})
      workspace = Pathname(Dir.pwd)
      update = (command == "update")
      LSqliteDb.shared.init_database
      repo_update = options[:repo_update] ||= false
      LgPodPlugin.log_green "当前工作目录 #{workspace}"
      podfile_path = check_podfile_exist?(workspace)
      return unless podfile_path
      project = LProject.shared.setup(workspace, podfile_path, update, repo_update)
      self.install_external_pod(project)
      # # 安装开发版本pod
      ReleasePod.install_release_pod(update, repo_update)
    end

    def self.install_external_pod(project)
      #下载 External pods
      LgPodPlugin.log_green "Pre-downloading External Pods" unless project.targets.empty?
      project.targets.each do |target|
        target.dependencies.each do |name, pod|
          installer = Installer.new
          installer.install(pod)
        end
      end
    end

    def self.check_podfile_exist?(workspace)
      podfile_path = workspace.join("Podfile")
      return podfile_path if podfile_path.exist?
      podfile_path = workspace.join("Podfile.rb")
      return podfile_path if podfile_path.exist?
      raise Informative, "No `Podfile' found in the project directory."
      return nil
    end

  end
end
