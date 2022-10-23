require 'cocoapods'
require 'cocoapods-core'

module LgPodPlugin

  class Main
    public
    def self.run(command, options = {})
      workspace = Pathname(Dir.pwd)
      update = (command == "update")
      repo_update = options[:repo_update] ||= false
      LgPodPlugin.log_green "当前工作目录 #{workspace}"
      podfile_path = workspace.join("Podfile")
      unless podfile_path.exist?
        podfile_path = workspace.join("Podfile.rb")
        unless podfile_path.exist?
          LgPodPlugin.log_red "no such file `Podfile`"
          return
        end
      end
      project = LProject.shared.setup(workspace, podfile_path, update, repo_update)
      self.install_external_pod(project)
      # # 安装开发版本pod
      # external_pods = Hash.new.merge!(install_hash_map).merge(local_pods)
      # self.install_external_pod(work_space, podfile, install_hash_map)
      # # 下载 release_pod
      # repo_update = options[:repo_update] ||= false
      ReleasePod.install_release_pod(update, repo_update)
      # LRequest.shared.destroy_all
    end

    def self.install_external_pod(project)
      #下载 External pods
      # LRequest.shared.libs = Hash.new.merge!(install_hash_map)
      LgPodPlugin.log_green "Pre-downloading External Pods" unless project.targets.empty?
      project.targets.each do |target|
        target.dependencies.each do |name, pod|
          installer = Installer.new
          installer.install(pod)
        end
      end
      # install_hash_map.each do |key, val|
      #   git = val[:git]
      #   tag = val[:tag]
      #   commit = val[:commit]
      #   if git && tag
      #     LRequest.shared.checkout_options = { :git => git, :tag => tag, :spec => nil, :release_pod => false }
      #     unless LCache.new(work_space).find_pod_cache(key, { :git => git, :tag => tag })
      #       LRequest.shared.libs.delete(key)
      #       next
      #     end
      #   elsif git && commit
      #     LRequest.shared.checkout_options = { :git => git, :commit => commit, :spec => nil, :release_pod => false }
      #     unless LCache.new(work_space).find_pod_cache(key, { :git => git, :commit => commit })
      #       LRequest.shared.libs.delete(key)
      #       next
      #     end
      #   end
      #   LgPodPlugin::Installer.new(podfile, key, val)
      # end
    end

  end
end
