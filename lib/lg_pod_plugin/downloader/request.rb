require 'net/http'
require 'cocoapods-core'

module LgPodPlugin

  class LRequest
    attr_reader :target
    attr_reader :name
    attr_accessor :podspec
    attr_reader :released_pod
    attr_accessor :single_git
    attr_accessor :config
    attr_accessor :net_ping
    attr_accessor :params
    attr_accessor :checkout_options
    def initialize(pod)
      @name = pod.name
      @podspec = pod.spec
      @target = pod.target
      @released_pod = pod.released_pod
      @checkout_options = pod.checkout_options
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
    # def get_lockfile
      # self.lockfile = LgPodPlugin::LockfileModel.from_file
    # end

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
      return nil unless git
      hash_map[:git] = git
      if git &&  commit
        hash_map[:commit] = commit
        return  hash_map
      elsif git && tag
        hash_map[:tag] = tag
        return  hash_map
      else
        return {:git => git}
      end
    end

    public
    def get_lock_params
      git = self.checkout_options[:git]
      tag = self.checkout_options[:tag]
      commit = self.checkout_options[:commit]
      branch = self.checkout_options[:branch]

      hash_map = Hash.new
      hash_map[:git] = git if git
      if git && tag
        hash_map[:tag] = tag
        return hash_map
      elsif git && branch
        hash_map[:branch] = branch
        _, new_commit = git_ls_remote_refs(self.name, git, branch)
        hash_map[:commit] = new_commit if new_commit
      elsif git && commit
        hash_map[:commit] = commit
        return hash_map
      else
        new_branch, new_commit = git_ls_remote_refs(self.name, git, nil)
        hash_map[:branch] = new_branch if new_branch
        hash_map[:commit] = new_commit if new_commit
      end
      hash_map
    end

    public

    #获取下载参数
    def get_request_params
      # unless self.lockfile
      #   self.lockfile = self.get_lockfile
      # end
      Hash.new.merge!(self.get_lock_params)
    end

    # 获取最新的一条 commit 信息
    def git_ls_remote_refs(name, git, branch)
      ip = self.net_ping.ip
      network_ok = self.net_ping.network_ok
      return [nil, nil] unless (ip && network_ok)
      if branch
        new_commit, _ = GitLabAPI.request_github_refs_heads git, branch, self.net_ping.uri
        # unless new_commit
        #   id = LPodLatestRefs.get_pod_id(name, git, branch)
        #   pod_info = LSqliteDb.shared.query_pod_refs(id)
        #   new_commit = pod_info ? pod_info.commit : nil
        #   return [branch, new_commit]
        # end
        # if new_commit
        #   LSqliteDb.shared.insert_pod_refs(name, git, branch, nil, new_commit)
        # end
        [branch, new_commit]
      else
        new_commit, new_branch = GitLabAPI.request_github_refs_heads git, nil, self.net_ping.uri
        # unless new_commit
        #   id = LPodLatestRefs.get_pod_id(name, git, "HEAD")
        #   pod_info = LSqliteDb.shared.query_pod_refs(id)
        #   new_commit = pod_info ? pod_info.commit : nil
        #   new_branch = pod_info ? pod_info.branch : nil
        #   return [new_branch, new_commit]
        # end
        # if new_commit
        #   LSqliteDb.shared.insert_pod_refs(name, git, "HEAD", nil, new_commit)
        # end
        [new_branch, new_commit]
      end
    end

  end

end
