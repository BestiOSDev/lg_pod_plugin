module LgPodPlugin

  class Spec

    REQUIRED_ATTRS ||= %i[install name git commit tag path branch].freeze
    attr_accessor(*REQUIRED_ATTRS)
    OPTIONAL_ATTRS ||= %i[depth configurations modular_headers subspecs inhibit_warnings testspecs].freeze
    attr_accessor(*OPTIONAL_ATTRS)
    def initialize(defined_in_file = nil, &block)
      if block
        instance_eval(&block)
      end
    end

    def inspect
      "#{self.class}: #{object_id} name: #{name}, tag: #{tag}"
    end

    def self.form_file(file_path)
      contents = File.open(file_path, 'r:utf-8', &:read)
      if contents.respond_to?(:encoding) && contents.encoding.name != 'UTF-8'
        contents.encoding("UTF-8")
      end
      # 2 讲xx.rb转成 Spec 对象
      l_spec = eval(contents, nil , file_path.to_s)
      if l_spec.install == nil
        l_spec.install = true
      end
      l_spec
    end

    # pod 必传参数
    def pod_requirements
      h = nil
      unless install != false
        return h
      end
      # 集成组件时, 【必选】参数, 必须互斥
      if path
        h = { path: path }
      elsif git && commit
        h = { git: git, commit: commit }
      elsif git && tag
        h = { git: git, tag: tag }
      elsif git && branch
        # branch is not supported for binary
        h = { git: git, branch: branch, depth: depth }
      else
        puts("VirusFile is not valid, `#{name}` will not be required\n")
      end

      pod_optional(h)

    end

    def pod_optional(h)
      OPTIONAL_ATTRS.each do |att|
        value = send(att)
        h[att] = value unless value.nil?
      end
      h
    end

  end

end
