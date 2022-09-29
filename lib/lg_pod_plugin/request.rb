require 'yaml'
require 'json'
require 'net/http'
require 'singleton'
require_relative 'l_config'
require_relative 'l_cache'
require_relative 'git_util'
require_relative 'downloader.rb'
module LgPodPlugin

  class LRequest
    include Singleton
    REQUIRED_ATTRS ||= %i[name request_params workspace cache downloader git_util lock_info checkout_options is_update token single_git libs config].freeze
    attr_accessor(*REQUIRED_ATTRS)

    public

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

    public

    def get_lock_info
      lock_file = self.workspace.join("Podfile.lock")
      if lock_file.exist?
        json = YAML.load_file(lock_file.to_path)
        external_source = json["EXTERNAL SOURCES"]
        checkout_options = json["CHECKOUT OPTIONS"]
        { "external_source" => external_source, "checkout_options" => checkout_options }
      else
        nil
      end
    end

    # 获取缓存用的hash_map

    public

    def get_cache_key_params
      hash_map = Hash.new
      git = self.checkout_options[:git] ||= self.request_params[:git]
      tag = self.checkout_options[:tag] ||= self.request_params[:tag]
      branch = self.checkout_options[:branch] ||= self.request_params[:branch]
      commit = self.checkout_options[:commit] ||= self.request_params[:commit]
      return hash_map unless git
      hash_map[:git] = git
      if git && commit
        hash_map[:commit] = commit
      elsif git && tag
        hash_map[:tag] = tag
      elsif git && branch
        if commit
          hash_map[:commit] = commit
        else
          _, new_commit_id = LGitUtil.git_ls_remote_refs(git, branch, nil, commit)
          hash_map[:commit] = new_commit_id if new_commit_id
        end
      else
        _, new_commit_id = LGitUtil.git_ls_remote_refs(git, branch, nil, commit)
        hash_map[:commit] = new_commit_id if new_commit_id
      end
      hash_map
    end

    public

    def get_lock_params
      unless self.lock_info
        self.lock_info = { "external_source" => {}, "checkout_options" => {} }
      end
      external_source = self.lock_info["external_source"][self.name] ||= {}
      checkout_options = self.lock_info["checkout_options"][self.name] ||= {}

      git = self.checkout_options[:git]
      tag = self.checkout_options[:tag]
      commit = self.checkout_options[:commit]
      branch = self.checkout_options[:branch]

      # lock_git = external_source[:git]
      # lock_tag = external_source[:tag]
      lock_commit = checkout_options[:commit]
      lock_branch = external_source[:branch]
      hash_map = Hash.new
      hash_map[:git] = git if git
      if git && tag
        hash_map[:tag] = tag
        return hash_map
      elsif git && branch
        if branch == lock_branch && !self.is_update
          hash_map[:branch] = branch if branch
          hash_map[:commit] = lock_commit if lock_commit
          return hash_map
        else
          hash_map[:branch] = branch if branch
          _, new_commit = LGitUtil.git_ls_remote_refs(git, branch, tag, commit)
          hash_map[:commit] = new_commit if new_commit
          return hash_map
        end
      elsif git && commit
        hash_map[:commit] = commit if commit
        return hash_map
      else
        new_branch, new_commit = LGitUtil.git_ls_remote_refs(git, branch, tag, commit)
        hash_map[:commit] = new_commit if new_commit
        hash_map[:branch] = new_branch if new_branch
      end
      hash_map
    end

    public

    #获取下载参数
    def get_request_params
      self.is_update = self.is_update_pod
      if self.lock_info == nil
        self.lock_info = self.get_lock_info
      end
      Hash.new.merge!(self.get_lock_params)
    end

    public

    def setup_pod_info(name, workspace, options = {})
      self.name = name
      tag = options[:tag]
      git = options[:git]
      commit = options[:commit]
      branch = options[:branch]
      self.workspace = workspace
      if (git && branch) || (git && commit) || (git && tag)
        self.single_git = false
      else
        self.single_git = true
      end
      self.checkout_options = Hash.new.deep_merge(options)
      self.request_params = self.get_request_params
      self.config = LConfig.getConfig(git)
      self.cache = LCache.new(self.workspace)
      self.git_util = LGitUtil.new(name, self.checkout_options)
      self.downloader = LDownloader.new(name, self.checkout_options)
    end

    def self.shared
      return LRequest.instance
    end

  end

end
