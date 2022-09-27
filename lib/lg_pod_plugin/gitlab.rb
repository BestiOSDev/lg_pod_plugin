require 'net/http'

module LgPodPlugin
  class GitLab

    def self.get_projects_with_group_id(token, group_id)

      begin
        #81.69.242.162
        uri = URI('http://81.69.242.162:8080/v1/member/user/gitlab/token')
        # uri = URI('http://127.0.0.1:8080/v1/member/user/gitlab/token')
        params = { "url" => git }
        res = Net::HTTP.post_form(uri, params)
        json = JSON.parse(res.body)
      rescue
        return nil
      end
      unless json
        return nil
      end
      json["data"]["token"]
    end
    def self.init_gitlab_projects(token, group_id)
      if token && group_id
        self.get_projects_with_group_id(token, group_id)
      end
    end



  end
end