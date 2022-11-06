require 'cocoapods'

module LgPodPlugin
  class LPodTarget
    attr_reader :name
    attr_reader :dependencies
    def initialize(target)
      internal_hash = target.send(:internal_hash)
      @name = internal_hash["name"]
      array = Array.new(internal_hash['dependencies'] ||= [])
      dependencies = array.reject do |e|
        if LUtils.is_a_string?(e)
          true
        elsif e.is_a?(Hash)
          key = e.keys.last ||= ""
          val = e[key].last ||= ""
          !val.is_a?(Hash)
        else
          true
        end
      end
      external_pods = Hash.new
      dependencies.each do |e|
        key = e.keys.last ||= ""
        val = e[key].last ||= {}
        next unless val.is_a?(Hash)
        pod = ExternalPod.new(self, key, val)
        external_pods[pod.name] = pod
      end
      @dependencies = external_pods
    end
  end
end
