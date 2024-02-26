require 'uri'
require_relative 'git_download'
require_relative '../utils/l_util'

module LgPodPlugin

  class GitHubArchive
    private

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
        self.github_download_tag_zip self.path
      elsif self.git && self.branch
        self.github_download_branch_zip self.path
      elsif self.git && self.commit
        self.github_download_commit_zip self.path
      end
    end

    def github_download_tag_zip(root_path)
      project_name = LUtils.get_git_project_name self.git
      download_urls = self.download_archive_zip(project_name)
      download_params = Hash.new
      download_params["name"] = self.name
      download_params["type"] = "github-tag"
      download_params["path"] = root_path.to_path
      download_params = download_params.merge(download_urls)
      download_params
    end

    def github_download_branch_zip(root_path)
      project_name = LUtils.get_git_project_name self.git
      download_urls = self.download_archive_zip(project_name)
      download_params = Hash.new
      download_params["name"] = self.name
      download_params["type"] = "github-branch"
      download_params["path"] = root_path.to_path
      download_params = download_params.merge(download_urls)
      download_params
    end

    def github_download_commit_zip(root_path)
      project_name = LUtils.get_git_project_name self.git
      download_urls = self.download_archive_zip(project_name)
      download_params = Hash.new
      download_params["name"] = self.name
      download_params["type"] = "github-commit"
      download_params["path"] = root_path.to_path
      download_params = download_params.merge(download_urls)
      download_params
    end

    # 下载某个文件zip格式
    def download_archive_zip(project_name)
      base_url = LUtils.get_gitlab_base_url(self.git)
      if base_url.include?("https://github.com/")
        repo_name = base_url.split("https://github.com/", 0).last
      elsif base_url.include?("git@github.com:")
        repo_name = base_url.split("git@github.com:", 0).last
      else
        repo_name = nil
      end
      return nil unless repo_name
      if self.git && self.tag
        download_url = "https://codeload.github.com/#{repo_name}/tar.gz/refs/tags/#{self.tag}"
        { "filename" => "#{project_name}.tar.gz", "url" => download_url }
      elsif self.git && self.branch
        if self.branch == "HEAD"
          download_url = "https://gh.api.99988866.xyz/" + "#{base_url}" + "/archive/#{self.branch}.tar.gz"
          { "filename" => "#{project_name}.tar.gz", "url" => download_url }
        else
          download_url = "https://codeload.github.com/#{repo_name}/tar.gz/refs/heads/#{self.branch}"
          { "filename" => "#{project_name}.tar.gz", "url" => download_url }
        end
      elsif self.git && self.commit
        download_url = "https://codeload.github.com/#{repo_name}/tar.gz/#{self.commit}"
        return { "filename" => "#{project_name}.tar.gz", "url" => download_url }
      else
        nil
      end
    end

  end
end
