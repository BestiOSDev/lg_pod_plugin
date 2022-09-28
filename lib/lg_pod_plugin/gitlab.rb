require 'net/http'
require 'json'
require_relative 'file_path'

module LgPodPlugin
  class GitLab

    def self.reqeust_gitlab_accesstoken(username, password, host)
      hash_map = {"grant_type" => "password", "username" => username, "password" => password}
      begin
        uri = URI("#{host}/oauth/token")
        res = Net::HTTP.post_form(uri, hash_map)
        json = JSON.parse(res.body)
        raise unless json["error"] == nil
        str = JSON.generate(json)
        path = LFileManager.gitlab_accesstoken_path
        File.open(path, 'w+') { |f| f.write(str) }
      rescue
        LgPodPlugin.log_red "生成 `access_token` 失败"
      end
    end

    end

end