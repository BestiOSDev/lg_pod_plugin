require 'uri'
require_relative 'git_download'
require_relative '../utils/l_util'

module LgPodPlugin

  class GitLabArchive

    private
    attr_reader :source_files
    attr_reader :podspec_content
    attr_reader :checkout_options

    public
    REQUIRED_ATTRS ||= %i[git tag name commit branch config path].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(checkout_options = {})
      self.git = checkout_options[:git]
      self.tag = checkout_options[:tag]
      self.name = checkout_options[:name]
      self.path = checkout_options[:path]
      self.config = checkout_options[:config]
      self.commit = checkout_options[:commit]
      self.branch = checkout_options[:branch]
      @checkout_options = checkout_options
    end

    def download
      if self.git && self.tag
        self.gitlab_download_tag_zip self.path
      elsif self.git && self.branch
        self.gitlab_download_branch_zip self.path
      elsif self.git && self.commit
        self.gitlab_download_commit_zip self.path
      else
        nil
      end
    end

    # 下载某个文件zip格式
    def download_archive_zip(sandbox_path)
      host = self.config.host
      project = self.config.project
      token = self.config.access_token
      unless host
        http = Ping.new(project.web_url)
        host = http.uri.scheme + "://" + http.uri.hostname
      end
      if self.git && self.tag
        sha = self.tag
      elsif self.git && self.branch
        sha = self.branch
      elsif self.git && self.commit
        sha = self.commit
      else
        return nil
      end
      download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2\\?" + "sha\\=#{sha}"
      download_url += "\\&access_token\\=#{token}" if token
      download_params = { "filename" => "#{self.name}.tar.bz2", "url" => download_url }
    end

    # 根据branch 下载 zip 包
    def gitlab_download_branch_zip(root_path)
      token = self.config.access_token
      download_urls = self.download_archive_zip(root_path)
      return nil unless download_urls
      download_params = Hash.new
      download_params["token"] = token
      download_params["name"] = self.name
      download_params["type"] = "gitlab-branch"
      download_params["path"] = root_path.to_path
      download_params = download_params.merge(download_urls)
      download_params
    end

    # 通过tag下载zip包
    def gitlab_download_tag_zip(root_path)
      token = self.config.access_token
      download_urls = self.download_archive_zip(root_path)
      return nil unless download_urls
      download_params = Hash.new
      download_params["token"] = token
      download_params["name"] = self.name
      download_params["type"] = "gitlab-tag"
      download_params["path"] = root_path.to_path
      download_params = download_params.merge(download_urls)
      download_params
    end

    # 通过 commit 下载zip包
    def gitlab_download_commit_zip(root_path)
      token = self.config.access_token
      download_urls = self.download_archive_zip(root_path)
      return nil unless download_urls
      download_params = Hash.new
      download_params["token"] = token
      download_params["name"] = self.name
      download_params["type"] = "gitlab-commit"
      download_params["path"] = root_path.to_path
      download_params = download_params.merge(download_urls)
      download_params
    end

  end

end
