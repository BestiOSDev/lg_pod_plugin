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
      local_pods = Hash.new
      release_pods = Hash.new
      install_hash_map = {}
      children = target.children
      children.each do |s|
        internal_hash = s.send(:internal_hash)
        next unless internal_hash.is_a?(Hash)
        dependencies = internal_hash["dependencies"]
        next unless dependencies.is_a?(Array)
        dependencies.each { |e|
          next unless e.is_a?(Hash)
          next if (key = e.keys.first) == nil
          pod_name = key
          val = e[key].last
          pod_name = key.split("/").first if key.include?("/")
          next unless val.is_a?(Hash)
          next unless val[:podspec] == nil
          if path = val[:path]
            local_pods[pod_name] = val
          else
            install_hash_map[pod_name] = val
          end
        }
      end
      # 安装开发版本pod
      external_pods = Hash.new.merge!(install_hash_map.merge!(local_pods))
      self.install_external_pod(work_space, podfile, install_hash_map)
      # 下载 release_pod
      repo_update = options[:repo_update] ||= false
      ReleasePod.install_release_pod(work_space, podfile,repo_update, is_update, Hash.new.merge!(external_pods), local_pods)
      LRequest.shared.destroy_all
    end

    def self.install_external_pod(work_space, podfile, install_hash_map)
      #下载 External pods
      LRequest.shared.libs = install_hash_map
      LgPodPlugin.log_green "Pre-downloading External Pods" unless install_hash_map.empty?
      install_hash_map.each do |key, val|
        git = val[:git]
        tag = val[:tag]
        commit = val[:commit]
        if git && tag
          LRequest.shared.checkout_options = { :git => git, :tag => tag, :spec => nil, :release_pod => false }
          unless LCache.new(work_space).find_pod_cache(key, { :git => git, :tag => tag })
            LRequest.shared.libs.delete(key)
            next
          end
        elsif git && commit
          LRequest.shared.checkout_options = { :git => git, :commit => commit, :spec => nil, :release_pod => false }
          unless LCache.new(work_space).find_pod_cache(key, { :git => git, :commit => commit })
            LRequest.shared.libs.delete(key)
            next
          end
        end
        LgPodPlugin::Installer.new(podfile, key, val)
      end
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