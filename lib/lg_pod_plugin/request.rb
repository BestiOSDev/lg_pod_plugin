require 'net/http'
require 'singleton'
require 'cocoapods-core'
require_relative 'l_config'
require_relative 'l_cache'
require_relative 'net-ping'
require_relative 'downloader'
require_relative 'gitlab_download'
module LgPodPlugin

  class LRequest
    include Singleton
    # pod name
    attr_accessor :name
    # 当前token
    attr_accessor :token
    # 缓存
    attr_accessor :cache
    # 配置
    attr_accessor :config
    # 是否更新
    attr_accessor :is_update
    # 工作目录
    attr_accessor :workspace
    # 是否是还有 git 地址参数
    attr_accessor :single_git
    # git 工具类
    attr_accessor :git_util
    # 需要更新的 pod 集合
    attr_accessor :libs
    # 下载类
    attr_accessor :downloader
    # lock_info
    attr_accessor :lock_info
    # 实际下载请求参数
    attr_accessor :request_params
    # 传入的请求参数
    attr_accessor :checkout_options
    # 网络ip 信息
    attr_accessor :net_ping

    public
    def get_lock_info
      lock_file_path = self.workspace.join("Podfile.lock")
      if lock_file_path.exist?
        lock_file = Pod::Lockfile.from_file(lock_file_path)
        internal_data = lock_file.send(:internal_data)
        release_pods = Hash.new
        pods = internal_data["PODS"] ||= {}
        pods.each do |key, val|
          if LUtils.is_string(key)
            pod_name = key.split(" ").first if key.include?(" ")
            tag = key[/(?<=\().*?(?=\))/]
            release_pods[pod_name] = tag
          elsif key.is_a?(Hash)
            key_name = key.keys.first
            next unless key_name
            pod_name = key_name.split(" ").first if key_name.include?(" ")
            tag = key_name[/(?<=\().*?(?=\))/]
            release_pods[pod_name] = tag
          else
            next
          end
        end
        external_source = internal_data["EXTERNAL SOURCES"] ||= {}
        checkout_options = internal_data["CHECKOUT OPTIONS"] ||= {}
        { "external_source" => external_source, "checkout_options" => checkout_options, "release_pods" => release_pods }
      else
        { "external_source" => {}, "checkout_options" => {}, "release_pods" => {} }
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
      elsif git && branch && commit
        hash_map[:commit] = commit
      end
      hash_map
    end

    public
    def get_lock_params
      begin
        _release_pods = self.lock_info["release_pods"] ||= {}
        _external_source = self.lock_info["external_source"][self.name] ||= {}
        _checkout_options = self.lock_info["checkout_options"][self.name] ||= {}
      rescue
        _release_pods = {}
        _external_source = {}
        _checkout_options = {}
      end

      git = self.checkout_options[:git]
      tag = self.checkout_options[:tag]
      commit = self.checkout_options[:commit]
      branch = self.checkout_options[:branch]
      lock_tag = _external_source[:tag] ||= _release_pods[self.name]
      lock_branch = _external_source[:branch] ||= ""
      lock_commit = _checkout_options[:commit] ||= ""
      hash_map = Hash.new
      hash_map[:git] = git if git
      if git && tag
        hash_map[:tag] = tag
        if tag != lock_tag
          hash_map["is_delete"] = false
        else
          hash_map["is_delete"] = true
        end
        return hash_map
      elsif git && branch
        hash_map[:branch] = branch
        if branch == lock_branch && !self.is_update
          if lock_commit && !lock_commit.empty?
            hash_map[:commit] = lock_commit
          end
          hash_map["is_delete"] = true
          return hash_map
        else
          _, new_commit = LGitUtil.git_ls_remote_refs(self.name ,git, branch, nil, nil)
          if new_commit && !new_commit.empty?
            hash_map[:commit] = new_commit
          elsif lock_commit && !lock_commit.empty?
            hash_map[:commit] = lock_commit
          end
          if !new_commit || !lock_commit || new_commit.empty? || lock_commit.empty?
            hash_map["is_delete"] = false
          elsif (new_commit != lock_commit)
            hash_map["is_delete"] = false
          else
            hash_map["is_delete"] = true
          end
        end
      elsif git && commit
        if commit != lock_commit
          hash_map["is_delete"] = false
        else
          hash_map["is_delete"] = true
        end
        hash_map[:commit] = commit
        return hash_map
      else
        new_branch, new_commit = LGitUtil.git_ls_remote_refs(self.name ,git, nil, nil, nil)
        hash_map[:branch] = new_branch if new_branch
        if new_commit && !new_commit.empty?
          hash_map[:commit] = new_commit
        elsif lock_commit && !lock_commit.empty?
          hash_map[:commit] = lock_commit
        end
        if !new_commit || !lock_commit || new_commit.empty? || lock_commit.empty?
          hash_map["is_delete"] = false
        elsif (new_commit != lock_commit)
          hash_map["is_delete"] = false
        else
          hash_map["is_delete"] = true
        end
      end
      hash_map
    end

    public
    #获取下载参数
    def get_request_params
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
      self.net_ping = Ping.new(git)
      self.net_ping.network_ok = self.net_ping.ping
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
