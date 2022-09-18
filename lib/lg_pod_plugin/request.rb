require 'singleton'
require 'yaml'
require_relative 'l_cache'
require_relative 'git_util'
require_relative 'download'
module LgPodPlugin

  class LRequest
    include Singleton
    REQUIRED_ATTRS ||= %i[name options workspace cache downloader git_util lock_info lock_params is_update].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def is_update_pod
      cgi = CGI.new
      command_keys = cgi.keys
      unless command_keys.count > 0
        return false
      end
      first_key = command_keys[0].to_s ||= ""
      if first_key.include?("install")
        false
      elsif first_key.include?("update")
        true
      else
        false
      end
    end

    def get_lock_info
      lock_file = self.workspace.join("Podfile.lock")
      if lock_file.exist?
        json = YAML.load_file(lock_file.to_path)
        external_sources = json["EXTERNAL SOURCES"]
        return external_sources
      else
        return nil
      end
    end

    def get_lock_params(git, branch, tag, commit)
      unless self.lock_info
        return nil
      end
      current_pod_info = self.lock_info[name]
      unless current_pod_info
        return nil
      end
      lock_commit = current_pod_info[:commit]
      if git && tag
        lock_tag = current_pod_info[:tag]
        if lock_tag == tag
          return { :git => git, :commit => lock_commit, :tag => lock_tag }
        else
          return nil
        end
      elsif git && branch
        lock_branch = current_pod_info[:branch]
        if branch == lock_branch
          return { :git => git, :commit => lock_commit, :branch => lock_branch}
        else
          return nil
        end
      elsif commit == lock_commit
        return { :git => git, :commit => lock_commit }
      else
        return nil
      end
    end

    def setup_pod_info(name, workspace, options = {})
      self.name = name
      hash_map = options
      tag = hash_map[:tag]
      git = hash_map[:git]
      path = hash_map[:path]
      commit = hash_map[:commit]
      branch = hash_map[:branch]
      self.workspace = workspace
      self.is_update = self.is_update_pod
      if self.lock_info == nil
        self.lock_info = self.get_lock_info
      end
      self.lock_params = self.get_lock_params(git, branch, tag, commit)
      if git && tag
        if self.lock_params && !self.is_update
          lock_tag = self.lock_params[:tag]
          lock_commit = self.lock_params[:commit]
          if lock_tag == tag && lock_commit
            hash_map[:commit] = lock_commit
          else
            new_branch, new_commit = LGitUtil.git_ls_remote_refs(git, branch, tag,commit)
            hash_map[:commit] = new_commit
          end
        else
          new_branch, new_commit = LGitUtil.git_ls_remote_refs(git, branch, tag,commit)
          hash_map[:commit] = new_commit
        end
      elsif git && commit
        if self.lock_params && !self.is_update
          hash_map[:commit] = commit
        else
          new_branch, new_commit = LGitUtil.git_ls_remote_refs(git, branch, tag, commit)
          if new_commit
            hash_map[:commit] = new_commit
          end
          if new_branch
            hash_map[:branch] = new_branch
          end
        end
      elsif git && branch
        if self.lock_params && !self.is_update
          lock_branch = self.lock_params[:branch]
          lock_commit = self.lock_params[:commit]
          if branch == lock_branch && lock_commit
            hash_map[:commit] = lock_commit
          else
            new_branch, new_commit = LGitUtil.git_ls_remote_refs(git, branch, tag, commit)
            hash_map[:commit] = new_commit
          end
        else
          new_branch, new_commit = LGitUtil.git_ls_remote_refs(git, branch, tag, commit)
          hash_map[:commit] = new_commit
        end
      else
        new_branch, new_commit = LGitUtil.git_ls_remote_refs(git, branch, tag, commit)
        hash_map[:commit] = new_commit
        hash_map[:branch] = new_branch
      end
      self.options = hash_map
      self.cache = LCache.new(self.workspace)
      self.git_util = LGitUtil.new(name, hash_map)
      self.downloader = LDownloader.new(name, hash_map)
    end

    def self.shared
      return LRequest.instance
    end

  end

end
