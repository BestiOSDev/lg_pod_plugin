require 'cocoapods-core'

module LgPodPlugin

  class LockfileModel
    attr_accessor :lockfile
    attr_accessor :release_pods
    attr_accessor :external_sources_data
    attr_accessor :checkout_options_data

    def initialize
    end

    def self.from_file
      lockfile = LProject.shared.lockfile
      unless lockfile
        lockfile_model = LockfileModel.new
        lockfile_model.lockfile = nil
        lockfile_model.release_pods = {}
        lockfile_model.checkout_options_data = {}
        lockfile_model.external_sources_data = {}
        return lockfile_model
      end
      release_pods = Hash.new
      pods = lockfile.send(:generate_pod_names_and_versions)
      pods.each do |element|
        if LUtils.is_a_string?(element) || element.is_a?(Hash)
          key = element.is_a?(Hash) ? element.keys.first : element
          next unless key
          if key.include?(" ")
            pod_name = LUtils.pod_real_name(key.split(" ").first)
          else
            pod_name = key
          end
          tag = key[/(?<=\().*?(?=\))/]
          release_pods[pod_name] = tag
        else
          next
        end
      end
      lockfile_model = LockfileModel.new
      lockfile_model.lockfile = lockfile
      lockfile_model.release_pods = release_pods
      lockfile_model.checkout_options_data = lockfile.send(:checkout_options_data)
      lockfile_model.checkout_options_data = {} unless lockfile_model.checkout_options_data
      lockfile_model.external_sources_data = lockfile.send(:external_sources_data)
      lockfile_model.external_sources_data = {} unless lockfile_model.external_sources_data
      lockfile_model
    end

    def checkout_options_for_pod_named(name)
      return {} unless @lockfile
      hash = @lockfile.checkout_options_for_pod_named(name)
      return hash ? hash : {}
    end


  end
end
