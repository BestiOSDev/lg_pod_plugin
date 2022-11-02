module LgPodPlugin

  class ExternalPod
    attr_reader :spec
    attr_reader :target
    attr_reader :name
    attr_reader :released_pod
    attr_reader :json_files
    attr_reader :source_files
    attr_reader :checkout_options
    attr_reader :prepare_command
    def initialize(target, name, hash,source_files = nil, json_files = nil)
      @spec = nil
      @target = target
      @released_pod = false
      @json_files = json_files
      @checkout_options = hash
      @source_files = source_files
      @name = LUtils.pod_real_name(name)
    end

  end

end
