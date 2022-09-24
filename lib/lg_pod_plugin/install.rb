require 'pp'
require 'git'
require 'cgi'
require 'cocoapods'
require_relative 'request'
require_relative 'database'
require_relative 'git_util'
require_relative 'downloader.rb'
require 'cocoapods-core/podfile/target_definition'
module LgPodPlugin

  class Installer

    REQUIRED_ATTRS ||= %i[name version options target real_name workspace].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(profile, name, requirements)
      unless name
        raise StandardError, 'A dependency requires a name.'
      end
      if name.include?("/")
        self.name = name.split("/").first
      else
        self.name = name
      end
      self.real_name = name
      self.workspace = profile.send(:defined_in_file).dirname
      self.target = profile.send(:current_target_definition)
      unless requirements && requirements.is_a?(Hash)
        LgPodPlugin.log_red "pod `#{name}`, 缺少必要的 [git|commit|tag|branch] 参数"
        return
      end
      hash_map = requirements
      hash_map.delete(:path)
      git = hash_map[:git]
      if git
        tag = hash_map[:tag]
        branch = hash_map[:branch]
        commit = hash_map[:commit]
        if tag
          hash_map.delete(:branch)
          hash_map.delete(:commit)
        elsif commit
          hash_map.delete(:tag)
          hash_map.delete(:branch)
        elsif branch
          hash_map.delete(:tag)
          hash_map.delete(:commit)
        else
          hash_map.delete(:tag)
          hash_map.delete(:branch)
          hash_map.delete(:commit)
        end
      end
      self.options = hash_map
      LRequest.shared.setup_pod_info(self.name, self.workspace, hash_map)
      self.install_remote_pod(name, hash_map)
    end

    public

    def install_remote_pod(name, options = {})
      if options[:git]
        LRequest.shared.downloader.pre_download_pod
      else
        LgPodPlugin.log_red "pod `#{name}`, 缺少必要的 [git|commit|tag|branch] 参数"
      end
    end

    public
    # 执行pod install/update命令
    def self.run_pod_install(update, libs, options = {})
      verbose = options[:verbose]
      repo_update = options[:repo_update]
      if update
        if libs.empty?
          LgPodPlugin.log_green "bundle exec arch -x86_64 pod update #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""} "
          system("bundle exec arch -x86_64 pod update #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""} ")
        else
          pod_names = libs.join(" ")
          LgPodPlugin.log_green "bundle exec arch -x86_64 pod update #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""} "
          system("bundle exec arch -x86_64 pod update #{pod_names} #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""} ")
        end
      else
        LgPodPlugin.log_green "bundle exec arch -x86_64 pod install #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""}"
        system("bundle exec arch -x86_64 pod install #{repo_update ? "--repo-update" : "--no-repo-update"} #{verbose ? "--verbose" : ""}")
      end
    end

    #执行lg install/update命令
    def self.run(command, options = {})
      work_space = Pathname(Dir.pwd)
      podfile_path = work_space.join("Podfile")
      unless podfile_path.exist?
        LgPodPlugin.log_red "no such file `Podfile`"
        return
      end

      podfile = Pod::Podfile.from_file(podfile_path)
      target = podfile.send(:current_target_definition)
      children = target.children
      install_hash_map = {}
      children.each do |s|
        internal_hash = s.send(:internal_hash)
        dependencies = internal_hash["dependencies"]
        next unless dependencies
        dependencies.each { |e|
          next unless e.is_a?(Hash)
          next if (key = e.keys.first) == nil
          next if (val = e[key].last) == nil
          next unless val.is_a?(Hash)
          install_hash_map[key] = val
        }
      end

      LgPodPlugin.log_red "预下载Pod"
      install_hash_map.each do |key, val|
        Installer.new(podfile, key, val)
      end

      LgPodPlugin.log_red "开始安装pod"
      #切换工作目录到当前工程下, 开始执行pod install
      FileUtils.chdir(podfile_path.dirname)
      libs = install_hash_map.keys ||= []
      # 执行pod install/ update 方法入口
      update_pod = (command == "update")
      run_pod_install(update_pod, libs, options)
    end

  end
end
