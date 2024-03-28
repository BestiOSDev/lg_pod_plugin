require 'uri'
require_relative '../utils/l_util'

module LgPodPlugin

  class GithubAPI

    # 获取 gitlab最新 commit_id
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
        request_url += ("/branches")
      else
        request_url += ("/commits/" + "HEAD")
      end
      LgPodPlugin.log_blue "http reqeust: #{request_url}"
      begin
        uri = URI(request_url)
        res = Net::HTTP.get_response(uri)
        case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          json = JSON.parse(res.body)
          if branch
            return [nil, nil] unless json.is_a?(Array)
            json.each do |element|
              name = element["name"]
              if name == branch
                commit = element["commit"]
                sha = commit["sha"]
                return [sha, commit]
              end
            end
            return [nil, branch]
          else
            return [nil, nil] unless json.is_a?(Hash)
            sha = json["sha"]
            return [sha, branch]
          end
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
      return [] unless repo_name
      begin
        uri = URI("https://api.github.com/repos/#{repo_name}/git/trees/#{sha}")
        res = Net::HTTP.get_response(uri)
        if res.body
          json = JSON.parse(res.body)
        else
          json = Hash.new
        end
        return [] unless json && json.is_a?(Hash)
        trees = json["tree"]
        if trees && trees.is_a?(Array)
          return trees
        else
          return []
        end
      rescue
        return []
      end
    end

  end

end
