require_relative 'git_clone'
require_relative 'gitlab_api'
require_relative 'gitlab_archive'
require_relative 'github_archive'
require_relative '../config/l_config'
require_relative '../downloader/request'

module  LgPodPlugin
  class GitDownloader
    attr_accessor :git
    attr_accessor :config
    attr_accessor :checkout_options
    def initialize(checkout_options = {})
      self.git = checkout_options[:git]
      self.config = checkout_options[:config]
      self.checkout_options = checkout_options
    end

    #开始下载
    public
    def download
      begin
        if self.is_use_gitlab_archive_file(self.git)
          git_archive = GitLabArchive.new(self.checkout_options)
          return git_archive.download
        elsif self.git.include?("https://github.com")
          github_archive = GitHubArchive.new(self.checkout_options)
          return github_archive.download
        else
          git_clone = GitRepository.new(checkout_options)
          return git_clone.download
        end
      rescue
        LgPodPlugin.log_red "异常信息: #{$!}"
        LgPodPlugin.log_yellow " 异常位置: #{$@}"
        git_clone = GitRepository.new(checkout_options)
        return  git_clone.download
      end
    end

    # 是否能够使用 gitlab 下载 zip 文件
    public
    def is_use_gitlab_archive_file(git)
      return false unless self.config&.access_token
      return true if self.config.project
      project_name = LUtils.get_git_project_name(git)
      self.config.project = GitLabAPI.request_project_info(config.host, project_name, config.access_token, git)
      (self.config.project != nil)
    end


  end
end
