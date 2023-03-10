require 'net/http'
# require 'singleton'
require 'cocoapods-core'

module LgPodPlugin

  class LRequest
    attr_reader :target
    attr_reader :name
    attr_accessor :lg_spec
    attr_reader :released_pod
    attr_accessor :single_git
    attr_accessor :config
    attr_accessor :net_ping
    attr_accessor :params
    attr_accessor :lockfile
    attr_accessor :checkout_options
    def initialize(pod)
      @name = pod.name
      @target = pod.target
      @released_pod = pod.released_pod
      @checkout_options = pod.checkout_options
      if pod.spec
        @lg_spec = pod.spec
      end
      self.preprocess_request
    end

    def preprocess_request
      http = self.checkout_options[:http]
      if http
        self.config = nil
        self.net_ping = nil
        self.single_git = false
        self.params = Hash.new
      else
        tag = self.checkout_options[:tag]
        git = self.checkout_options[:git]
        commit = self.checkout_options[:commit]
        branch = self.checkout_options[:branch]
        if (git && branch) || (git && commit) || (git && tag)
          self.single_git = false
        else
          self.single_git = true
        end
        self.net_ping = Ping.new(git)
        self.config = LConfig.get_config(git, self.net_ping.uri)
        self.params = self.get_request_params
      end
    end

    public
    def get_lockfile
      self.lockfile = LgPodPlugin::LockfileModel.from_file
    end

    # 获取缓存用的hash_map
    public
    def get_cache_key_params
      options = Hash.new.merge!(self.checkout_options)
      hash_map = Hash.new
      http = options[:http]
      if http
        hash_map[:http] = http
        return hash_map
      end
      git = options[:git] ||= self.params[:git]
      tag = options[:tag] ||= self.params[:tag]
      branch = options[:branch] ||= self.params[:branch]
      commit = options[:commit] ||= self.params[:commit]
      return hash_map unless git
      hash_map[:git] = git
      if git && commit
        hash_map[:commit] = commit
      elsif git && tag
        hash_map[:tag] = tag
      elsif git && branch && commit
        hash_map[:commit] = commit
      end
      hash_map
    end

    public
    def get_lock_params
      begin
        _release_pods = self.lockfile.release_pods ||= []
        _external_source = (self.lockfile.external_sources_data[self.name])
        _external_source = {} unless _external_source
        _checkout_options = self.lockfile.checkout_options_for_pod_named(self.name)
      rescue
        _release_pods = {}
        _external_source = {}
        _checkout_options = {}
      end

      git = self.checkout_options[:git]
      tag = self.checkout_options[:tag]
      commit = self.checkout_options[:commit]
      branch = self.checkout_options[:branch]

      lock_git = _external_source[:git] ||= _checkout_options[:git]
      lock_tag = _external_source[:tag] ||= _release_pods[self.name]
      lock_branch = _external_source[:branch] ||= ""
      lock_commit = _checkout_options[:commit] ||= ""

      hash_map = Hash.new
      hash_map[:git] = git if git
      if git && tag
        hash_map[:tag] = tag
        return hash_map
      elsif git && branch
        hash_map[:branch] = branch
        if lock_commit && !lock_commit.empty? && !LProject.shared.update
          pod_info = LSqliteDb.shared.query_branch_with_sha(self.name, git, lock_commit)
          lock_branch = pod_info[:branch] if lock_branch.empty?
          new_commit = pod_info[:sha] ||= ""
          if lock_branch == branch && new_commit == lock_commit
            hash_map[:commit] = lock_commit
            return hash_map
          end
        end
        _, new_commit = git_ls_remote_refs(self.name, git, branch)
        if new_commit && !new_commit.empty?
          hash_map[:commit] = new_commit
        elsif lock_commit && !lock_commit.empty?
          hash_map[:commit] = lock_commit
        end
      elsif git && commit
        hash_map[:commit] = commit
        return hash_map
      else
        if lock_git && !LProject.shared.update
          id = LPodLatestRefs.get_pod_id(self.name, git)
          pod_info = LSqliteDb.shared.query_pod_refs(id)
          if pod_info&.commit
            if pod_info
              new_commit = pod_info.commit
            else
              new_commit = nil
            end
            if pod_info
              new_branch = pod_info.branch
            else
              new_branch = nil
            end
            if new_commit
              hash_map[:commit] = new_commit
            end
            if new_branch
              hash_map[:branch] = new_branch
            end
            return hash_map
          end
        end
        new_branch, new_commit = git_ls_remote_refs(self.name, git, nil)
        hash_map[:branch] = new_branch if new_branch
        if new_commit && !new_commit.empty?
          hash_map[:commit] = new_commit
        end
      end
      hash_map
    end

    public

    #获取下载参数
    def get_request_params
      unless self.lockfile
        self.lockfile = self.get_lockfile
      end
      Hash.new.merge!(self.get_lock_params)
    end

    # 获取最新的一条 commit 信息
    def git_ls_remote_refs(name, git, branch)
      ip = self.net_ping.ip
      network_ok = self.net_ping.network_ok
      return [nil, nil] unless (ip && network_ok)
      if branch
        new_commit, _ = GitLabAPI.request_github_refs_heads git, branch, self.net_ping.uri
        unless new_commit
          id = LPodLatestRefs.get_pod_id(name, git)
          pod_info = LSqliteDb.shared.query_pod_refs(id)
          new_commit = pod_info ? pod_info.commit : nil
          return [branch, new_commit]
        end
        if new_commit
          LSqliteDb.shared.insert_pod_refs(name, git, branch, nil, new_commit)
        end
        [branch, new_commit]
      else
        new_commit, new_branch = GitLabAPI.request_github_refs_heads git, nil, self.net_ping.uri
        unless new_commit
          id = LPodLatestRefs.get_pod_id(name, git)
          pod_info = LSqliteDb.shared.query_pod_refs(id)
          new_commit = pod_info ? pod_info.commit : nil
          new_branch = pod_info ? pod_info.branch : nil
          return [new_branch, new_commit]
        end
        if new_commit
          LSqliteDb.shared.insert_pod_refs(name, git, new_branch, nil, new_commit)
        end
        [new_branch, new_commit]
      end
    end

  end

end
