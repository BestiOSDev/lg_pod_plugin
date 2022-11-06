
require_relative '../config/podspec'

module LgPodPlugin

  class ExternalPod
    attr_reader :spec
    attr_reader :target
    attr_reader :name
    attr_reader :released_pod
    attr_reader :checkout_options
    def initialize(target, name, hash)
      @target = target
      @released_pod = false
      @checkout_options = hash
      @name = LUtils.pod_real_name(name)
    end

  end

end
