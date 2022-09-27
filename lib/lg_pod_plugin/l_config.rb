require 'json'

module LgPodPlugin

  class LConfig
    attr_accessor :group_id
    attr_accessor :projects
    attr_accessor :group_name
    attr_accessor :private_token
    def self.form_json_file(file_path)
      return nil unless File.exist?(file_path)
      json = File.read(file_path)
      begin
        obj = JSON.parse(json)
        config = LConfig.new
        config.group_id = obj["group_id"]
        config.group_name = obj["group_name"]
        config.private_token = obj["private_token"]
        config.projects = obj["projects"] ||= {}
        return config
      rescue
        return nil
      end
    end

  end
end