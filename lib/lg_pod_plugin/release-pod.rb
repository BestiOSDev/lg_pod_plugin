require 'cocoapods'
require 'cocoapods-core'
require_relative 'l_util'
require_relative 'l_cache'
require_relative 'specification'

module LgPodPlugin
  class ReleasePod

    def self.install_release_pod(work_space, podfile, repo_update, update, external_pods)
      #切换工作目录到当前工程下, 开始执行pod install
      FileUtils.chdir(work_space)
      # 安装 relase_pod
      LgPodPlugin.log_green "Pre-downloading Release Pods"
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
      root_specs = root_specs.reject! do |spec|
        spec_name = spec.send(:attributes_hash)["name"]
        external_pods[spec_name] || external_pods[spec_name.split("/").first]
      end unless external_pods.empty?
      return unless root_specs
      root_specs.sort_by(&:name).each do |spec|
        attributes_hash = spec.send(:attributes_hash)
        next unless attributes_hash.is_a?(Hash)
        pod_name = attributes_hash["name"] ||= ""
        checksum = spec.send(:checksum)
        if lock_file && checksum
          internal_data = lock_file.send(:internal_data)
          lock_checksums = internal_data["SPEC CHECKSUMS"] ||= {}
          lock_checksum = lock_checksums[pod_name]
          next if lock_checksum == checksum
        end
        pod_version = attributes_hash["version"]
        prepare_command = attributes_hash['prepare_command']
        next if prepare_command
        source = attributes_hash['source']
        next unless source.is_a?(Hash)
        git = source["git"] ||= ""
        tag = source["tag"] ||= ""
        next unless git.include?("https://github.com")
        requirements = { :git => git, :tag => tag, :release_pod => true, :spec => spec }
        LRequest.shared.checkout_options = requirements
        next unless LCache.new(work_space).find_pod_cache(pod_name, { :git => git, :tag => tag })
        LRequest.shared.libs[pod_name] = requirements
        LgPodPlugin::Installer.new(podfile, pod_name, requirements)
      end

    end

  end

end