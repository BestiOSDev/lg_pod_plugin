require 'singleton'

require_relative 'l_cache'
require_relative 'git_util'
require_relative 'download'
module  LgPodPlugin
  
  class LRequest
    include Singleton
    REQUIRED_ATTRS ||= %i[name options workspace cache downloader git_util].freeze
    attr_accessor(*REQUIRED_ATTRS)
    
    def setup_pod_info(name,workspace, options = {})
      self.name = name
      hash_map = options
      tag = hash_map[:tag]
      git = hash_map[:git]
      path = hash_map[:path]
      commit = hash_map[:commit]
      branch = hash_map[:branch]
      self.workspace = workspace
      if (!commit || !branch) && !path
        new_branch, new_commit = LGitUtil.git_ls_remote_refs(git, branch, tag)
        if new_branch != nil
          branch = new_branch
          hash_map[:branch] = branch
        end
        if new_commit != nil
          commit = new_commit
          hash_map[:commit] = commit
        end
      end
      self.options = hash_map
      self.cache = LCache.new(self.workspace)
      self.downloader = LDownloader.new(name, hash_map)
      self.git_util = LGitUtil.new(name, hash_map)
    end

    def self.shared
      return LRequest.instance
    end

  end

end
