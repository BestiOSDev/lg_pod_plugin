require 'cocoapods'
require 'cocoapods-core'
require_relative 'l_util'
require_relative 'l_cache'

module LgPodPlugin

  class ReleasePod

    def self.check_release_pod_exist(work_space, pod_name, git, tag, spec, requirements)
      LRequest.shared.checkout_options = requirements
      return !(LCache.new(work_space).find_pod_cache(pod_name, { :git => git, :tag => tag }))
    end

    def self.resolve_dependencies(work_space, podfile, lockfile, installer, external_pods)
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
        pod_name = attributes_hash["name"]
        pod_version = attributes_hash["version"]
        source = attributes_hash['source']
        next unless source.is_a?(Hash)
        git = source["git"]
        tag = source["tag"]
        next unless (git && tag) && (git.include?("https://github.com"))
        checksum = spec.send(:checksum)
        requirements = { :git => git, :tag => tag, :release_pod => true, :spec => spec }
        pod_exist = check_release_pod_exist(work_space, pod_name, git, tag, spec, requirements)
        if lockfile && checksum
          internal_data = lockfile.send(:internal_data)
          lock_checksums = internal_data["SPEC CHECKSUMS"] ||= {}
          lock_checksum = lock_checksums[pod_name]
          next if (lock_checksum == checksum) && (pod_exist)
        else
          next if pod_exist
        end
        LgPodPlugin::Installer.new(podfile, pod_name, requirements)
      end

    end

    def self.dependencies(installer)
      installer.download_dependencies
      installer.send(:validate_targets)
      installation_options = installer.send(:installation_options)
      skip_pods_project_generation = installation_options.send(:skip_pods_project_generation)
      if skip_pods_project_generation
        installer.show_skip_pods_project_generation_message
      else
        installer.integrate
      end
      installer.send(:write_lockfiles)
      installer.send(:perform_post_install_actions)
    end

    def self.install_release_pod(work_space, podfile, repo_update, update, external_pods, local_pods)
      #切换工作目录到当前工程下, 开始执行pod install
      FileUtils.chdir(work_space)
      # 安装 relase_pod
      LgPodPlugin.log_green "Pre-downloading Release Pods"
      Pod::Config.instance.verbose = true
      pods_path = work_space.join('Pods')
      lockfile_path = work_space.join("Podfile.lock")
      lock_file = Pod::Lockfile.from_file(lockfile_path) if lockfile_path.exist?
      sandobx = Pod::Sandbox.new(pods_path)
      installer = Pod::Installer.new(sandobx, podfile, lock_file)
      installer.repo_update = repo_update
      if update
        if external_pods.empty?
          installer.update = true
        else
          pods = LRequest.shared.libs.merge!(local_pods)
          installer.update = { :pods => pods.keys }
        end
      else
        installer.update = false
      end
      installer.deployment = false
      installer.clean_install = false
      installer.prepare
      resolve_dependencies(work_space, podfile, lock_file, installer, external_pods)
      dependencies(installer)
    end

  end

end
