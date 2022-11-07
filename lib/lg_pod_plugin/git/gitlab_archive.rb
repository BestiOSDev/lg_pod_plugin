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

    REQUIRED_ATTRS ||= %i[git tag name commit branch config path spec].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(checkout_options = {})
      self.git = checkout_options[:git]
      self.tag = checkout_options[:tag]
      self.name = checkout_options[:name]
      self.path = checkout_options[:path]
      self.spec = checkout_options[:spec]
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

      lg_spec = self.spec
      unless lg_spec
        podspec_filename = self.name + ".podspec"
        podspec_content = GitLabAPI.get_podspec_file_content(host, token, project.id, sha, podspec_filename)
        unless podspec_content && LUtils.is_a_string?(podspec_content)
          download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2?" + "sha=#{sha}"
          return [{ "filename" => "#{self.name}.tar.bz2", "url" => download_url }]
        end
        pod_spec_file_path = sandbox_path.join("#{podspec_filename}")
        lg_spec = LgPodPlugin::PodSpec.form_string(podspec_content, pod_spec_file_path)
        unless lg_spec
          if podspec_content
            begin
              File.open(pod_spec_file_path, "w+") do |f|
                f.write podspec_content
              end
            rescue => exception
              LgPodPlugin.log_red "#{exception}"
            end
            @podspec_content = podspec_content
          end
          download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2?" + "sha=#{sha}"
          return [{ "filename" => "#{self.name}.tar.bz2", "url" => download_url }]
        end
        self.spec = lg_spec
      end
      download_params = Array.new
      @source_files = lg_spec.source_files.keys
      lg_spec.source_files.each_key do |key|
        path = LUtils.url_encode(key)
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2#{"\\?"}" + "path#{"\\="}#{path}#{"\\&"}sha#{"\\="}#{sha}"
        download_params.append({ "filename" => "#{key}.tar.bz2", "url" => download_url })
      end
      if download_params.empty?
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2?" + "sha=#{sha}"
        [{ "filename" => "#{self.name}.tar.bz2", "url" => download_url }]
      else
        download_params
      end
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
      if self.spec
        download_params["podspec"] = self.spec
      else
        download_params["podspec_content"] = @podspec_content
      end
      download_params["path"] = root_path.to_path
      if @source_files
        download_params["source_files"] = @source_files
      else
        download_params["source_files"] = "All"
      end
      download_params["download_urls"] = download_urls
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
      if self.spec
        download_params["podspec"] = self.spec
      else
        download_params["podspec_content"] = @podspec_content
      end
      download_params["path"] = root_path.to_path
      if @source_files
        download_params["source_files"] = @source_files
      else
        download_params["source_files"] = "All"
      end
      download_params["download_urls"] = download_urls
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
      if self.spec
        download_params["podspec"] = self.spec
      else
        download_params["podspec_content"] = @podspec_content
      end
      download_params["type"] = "gitlab-commit"
      download_params["path"] = root_path.to_path
      if @source_files
        download_params["source_files"] = @source_files
      else
        download_params["source_files"] = "All"
      end
      download_params["download_urls"] = download_urls
      download_params
    end

  end

end
