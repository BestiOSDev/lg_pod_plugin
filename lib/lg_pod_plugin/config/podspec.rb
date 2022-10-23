require 'cocoapods'
require 'cocoapods-core'

module LgPodPlugin

  class PodSpec
    attr_accessor :source_files
    def self.form_file(path)
      spec = Pod::Specification.from_file(path)
      return PodSpec.new(spec)
    end

    def initialize(spec)
      set = Set[]
      attributes_hash = spec.send(:attributes_hash)
      return nil unless attributes_hash.is_a?(Hash)
      license = attributes_hash["license"]
      if license.is_a?(Hash)
        license_file = license["file"]
        set.add(license_file) if license_file
      else
        set.add("LICENSE")
      end
      # 解析主模块依赖信息
      set.merge(parse_subspec_with(attributes_hash))
      subspecs = spec.subspecs
      unless subspecs.is_a?(Array)
        self.source_files = set
        return
      end
      subspecs.each do |sub_spec|
        next unless sub_attributes_hash = sub_spec.send(:attributes_hash)
        next unless sub_attributes_hash.is_a?(Hash)
        sub_set = self.parse_subspec_with(sub_attributes_hash)
        next if sub_set.empty?
        set.merge(sub_set)
      end
      self.source_files = set
    end

    # 公共解析解析subspec
    def parse_subspec_with(hash)
      set = Set[]
      source_files = self.parse_source_files(hash["source_files"])
      set.merge(source_files) unless source_files.empty?
      resources = self.parse_resource_files(hash["resource"] ||= hash["resources"])
      set.merge(resources) unless resources.empty?
      resource_bundles = self.parse_resource_bundles(hash["resource_bundle"] ||= hash["resource_bundles"])
      set.merge(resource_bundles) unless resource_bundles.empty?
      project_header_files = self.parse_project_header_files(hash["project_header_files"])
      set.merge(resource_bundles) unless project_header_files.empty?
      private_header_files = self.parse_private_header_files(hash["private_header_files"])
      set.merge(private_header_files) unless private_header_files.empty?
      vendored_frameworks = self.parse_vendored_frameworks(hash["vendored_frameworks"])
      set.merge(vendored_frameworks) unless vendored_frameworks.empty?
      vendored_library = self.parse_vendored_library(hash["vendored_library"] ||= hash["vendored_libraries"])
      set.merge(vendored_library) unless vendored_library.empty?
      #parse_preserve_path
      preserve_paths = self.parse_preserve_path(hash["preserve_path"] ||= hash["preserve_paths"])
      set.merge(preserve_paths) unless preserve_paths.empty?
      module_map = self.parse_module_map(hash["module_map"])
      set.merge(module_map) unless module_map.empty?
      return set
    end

    # 公共解析文件路径的方法
    def parse_public_source_filse(source_files)
      return [] unless source_files
      array = []
      if LUtils.is_a_string?(source_files)
        if source_files.include?("/")
          array.append(source_files.split("/").first)
        else
          array.append(source_files)
        end
      elsif source_files.is_a?(Array)
        source_files.each do |element|
          next unless LUtils.is_a_string?(element)
          if element.include?("/")
            array.append(element.split("/").first)
          else
            array.append(element)
          end
        end
      elsif source_files.is_a?(Hash)
        source_files.each do |key,val|
          if LUtils.is_a_string?(val)
            if val.include?("/")
              array.append(val.split("/").first)
            else
              array.append(val)
            end
          elsif val.is_a?(Array)
            val.each do |element|
              next unless LUtils.is_a_string?(element)
              if element.include?("/")
                array.append(element.split("/").first)
              else
                array.append(element)
              end
            end
          end
        end
      end
      return array
    end

    # 解析source_fils路径
    def parse_source_files(source_files)
      return self.parse_public_source_filse(source_files)
    end

    # 解析 resource所在路径
    def parse_resource_files(source_files)
      return self.parse_public_source_filse(source_files)
    end

    # 解析public_header_files字段的值
    def parse_public_header_files(source_files)
      return self.parse_public_source_filse(source_files)
    end
    # 解析 parse_resource_bundles
    def parse_resource_bundles(source_files)
      return self.parse_public_source_filse(source_files)
    end
    # 解析 project_header_files
    def parse_project_header_files(source_files)
      return self.parse_public_source_filse(source_files)
    end

    # 解析 private_header_files
    def parse_private_header_files(source_files)
      return self.parse_public_source_filse(source_files)
    end
    # 解析 vendored_frameworks
    def parse_vendored_frameworks(source_files)
      return self.parse_public_source_filse(source_files)
    end
    # 解析 parse_vendored_library
    def parse_vendored_library(source_files)
      return self.parse_public_source_filse(source_files)
    end

    # 解析 parse_preserve_path
    def parse_preserve_path(source_files)
      return self.parse_public_source_filse(source_files)
    end

    # 解析 module_map
    def parse_module_map(source_files)
      return self.parse_public_source_filse(source_files)
    end

  end

end
