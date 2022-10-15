require 'cocoapods'
require 'cocoapods-core'
module LgPodPlugin
  class ReleasePod

    def self.install_release_pod(work_space, podfile, update, repo_update, external_pods)
      # 安装 relase_pod
      LgPodPlugin.log_green "Pre-downloading Release Pods"
      #切换工作目录到当前工程下, 开始执行pod install
      FileUtils.chdir(work_space)
      Pod::Config.instance.verbose = false
      pods_path = work_space.join('Pods')
      lockfile_path = work_space.join("Podfile.lock")
      lock_file = Pod::Lockfile.from_file(lockfile_path) if lockfile_path.exist?
      sandobx = Pod::Sandbox.new(pods_path)
      installer = Pod::Installer.new(sandobx, podfile, lock_file)
      installer.repo_update = repo_update
      installer.update = update
      installer.deployment = false
      installer.clean_install = false
      installer.prepare
      installer.resolve_dependencies
      analysis_result = installer.send(:analysis_result)
      return unless analysis_result
      root_specs = analysis_result.specifications.map(&:root).uniq
      return unless root_specs
      root_specs.sort_by(&:name).each do |spec|
        attributes_hash = spec.send(:attributes_hash)
        next unless attributes_hash.is_a?(Hash)
        pod_name = attributes_hash["name"]
        if pod_name.include?("/")
          real_name = pod_name.split("/").first
        else
          real_name = pod_name
        end
        next if external_pods[real_name]
        pod_version = attributes_hash["version"]
        prepare_command = attributes_hash['prepare_command']
        next if prepare_command
        source = attributes_hash['source']
        next unless source.is_a?(Hash)
        git = source["git"] ||= ""
        tag = source["tag"] ||= ""
        next unless git.include?("https://github.com")
        requirements = {:git => git, :tag => tag, :release_pod => true, :spec => spec}
        LRequest.shared.libs[real_name] = requirements
        LgPodPlugin::Installer.new(podfile, real_name, requirements)
      end
    end
  end
end