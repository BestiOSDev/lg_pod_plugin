require 'cocoapods'
require 'cocoapods-core'
require_relative 'l_util'
require_relative 'install'
require_relative 'request'
require_relative 'release-pod'

module LgPodPlugin
  class Main

    public
    def self.run(command, options = {})
      is_update = (command == "update")
      work_space = Pathname(Dir.pwd)
      LgPodPlugin.log_green "当前工作目录 #{work_space}"
      podfile_path = work_space.join("Podfile")
      unless podfile_path.exist?
        LgPodPlugin.log_red "no such file `Podfile`"
        return
      end
      LRequest.shared.is_update = is_update
      podfile = Pod::Podfile.from_file(podfile_path)
      target = podfile.send(:current_target_definition)
      local_pods = Set[]
      release_pods = Set[]
      install_hash_map = {}
      children = target.children
      children.each do |s|
        internal_hash = s.send(:internal_hash)
        next unless internal_hash.is_a?(Hash)
        dependencies = internal_hash["dependencies"]
        next unless dependencies.is_a?(Array)
        dependencies.each { |e|
          release_pods.add(e) if LUtils.is_string(e)
          next unless e.is_a?(Hash)
          next if (key = e.keys.first) == nil
          next if (val = e[key].last) == nil
          if key.include?("/")
            key = key.split("/").first
          end
          if val.is_a?(Hash)
            next unless val[:podspec] == nil
            path = val[:path]
            local_pods.add(key) if path
            next unless path == nil
            install_hash_map[key] = val
          else
            release_pods.add(key) if key
          end
        }
      end
      #下载 External pods
      LRequest.shared.libs = Hash.new.merge!(install_hash_map)
      LgPodPlugin.log_green "Pre-downloading External Pods" unless install_hash_map.empty?
      install_hash_map.each do |key, val|
        LgPodPlugin::Installer.new(podfile, key, val)
      end
      # 下载 release_pod
      repo_update = options[:repo_update] ||= false
      ReleasePod.install_release_pod(work_space, podfile, is_update, repo_update, install_hash_map) unless release_pods.empty?
      LgPodPlugin.log_green "开始安装Pod"

      #切换工作目录到当前工程下, 开始执行pod install
      FileUtils.chdir(work_space)
      libs = Set[]
      libs += Array(local_pods)
      libs += LRequest.shared.libs.keys
      # 执行pod install/ update 方法入口
      update_pod = (command == "update")
      run_pod_install(update_pod, libs, options)
    end

    public
    # 执行pod install/update命令
    def self.run_pod_install(update, libs, options = {})
      verbose = options[:verbose]
      repo_update = options[:repo_update]
      if update
        if libs.empty?
          LgPodPlugin.log_red "no external pod update, you can use `pod update` to update --all pods"
          system("bundle exec arch -x86_64 pod update #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""} ")
        else
          pod_names = Array(libs).join(" ")
          LgPodPlugin.log_green Array(libs).join("\n")
          LgPodPlugin.log_green "bundle exec arch -x86_64 pod update #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""} "
          system("bundle exec arch -x86_64 pod update #{pod_names} #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""} ")
        end
      else
        LgPodPlugin.log_green "bundle exec arch -x86_64 pod install #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""}"
        system("bundle exec arch -x86_64 pod install #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""}")
      end
    end

  end
end