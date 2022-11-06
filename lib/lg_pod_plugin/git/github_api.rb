require 'uri'
require_relative '../utils/l_util'

module LgPodPlugin

  class GithubAPI

    #获取 gitlab最新 commit_id
    def self.request_github_refs_heads(git, branch)
      base_url = LUtils.get_gitlab_base_url git
      if base_url.include?("https://github.com/")
        repo_name = base_url.split("https://github.com/", 0).last
      elsif base_url.include?("git@github.com:")
        repo_name = base_url.split("git@github.com:", 0).last
      else
        repo_name = nil
      end
      return [nil, nil] unless repo_name
      request_url = "https://api.github.com/repos/" + repo_name
      if branch
        request_url += ("/commits/" + branch)
      else
        request_url += ("/commits/" + "HEAD")
      end
      begin
        uri = URI(request_url)
        res = Net::HTTP.get_response(uri)
        case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          json = JSON.parse(res.body)
          return [nil, nil] unless json.is_a?(Hash)
          sha = json["sha"]
          return [sha, branch]
        else
          return [nil, nil]
        end
      rescue
        return [nil, nil]
      end

    end

    public
    def self.get_gitlab_repository_tree(git, sha)
      base_url = LUtils.get_gitlab_base_url git
      if base_url.include?("https://github.com/")
        repo_name = base_url.split("https://github.com/", 0).last
      elsif base_url.include?("git@github.com:")
        repo_name = base_url.split("git@github.com:", 0).last
      else
        repo_name = nil
      end
      return Set.new unless repo_name
      begin
        uri = URI("https://api.github.com/repos/#{repo_name}/git/trees/#{sha}")
        res = Net::HTTP.get_response(uri)
        if res.body
          json = JSON.parse(res.body)
        else
          json = nil
        end
        return Set.new unless json && json.is_a?(Hash)
        files = json["tree"].collect { |dict|
          dict["path"]
        }
        set = Set.new.merge files
        return set
      rescue
        return Set.new
      end
    end

    public
    def self.get_podspec_file_content(git, sha, filename)
      base_url = LUtils.get_gitlab_base_url git
      if base_url.include?("https://github.com/")
        repo_name = base_url.split("https://github.com/", 0).last
      elsif base_url.include?("git@github.com:")
        repo_name = base_url.split("git@github.com:", 0).last
      else
        repo_name = nil
      end
      return Set.new unless repo_name
      begin
        uri = URI("https://raw.githubusercontent.com/#{repo_name}/#{sha}/#{filename}")
        res = Net::HTTP.get_response(uri)
        if res.body != nil
          if LUtils.is_a_string?(res.body)
            if res.body.respond_to?(:encoding) && res.body.encoding.name != 'UTF-8'
              text = res.body.force_encoding("gb2312").force_encoding("utf-8")
              return text
            else
              return res.body
            end
          else
            return nil
          end
        else
          return nil
        end
      rescue
        return nil
      end
    end

  end

end
