require 'uri'
require_relative 'git_download'
require_relative '../uitils/l_util'

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
        return self.gitlab_download_tag_zip self.path
      elsif self.git && self.branch
        return self.gitlab_download_branch_zip self.path
      elsif self.git && self.commit
        return self.gitlab_download_commit_zip self.path
      else

      end
    end

    # 下载某个文件zip格式
    def gitlab_download_repository_archive_zip(sanbox_path, project_name)
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

      trees = GitLabAPI.get_gitlab_repository_tree host, token, project.id, sha
      if trees.empty?
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2?" + "sha=#{sha}"
        return [{ "filename" => "#{self.name}.tar.bz2", "url" => download_url }]
      end
      podspec_filename = self.name + ".podspec"
      unless trees.include?(podspec_filename)
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2?" + "sha=#{sha}"
        return [{ "filename" => "#{self.name}.tar.bz2", "url" => download_url }]
      end
      podspec_content = GitLabAPI.get_podspec_file_content(host, token, project.id,sha, podspec_filename)
      unless podspec_content && LUtils.is_a_string?(podspec_content)
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2?" + "sha=#{sha}"
        return [{ "filename" => "#{self.name}.tar.bz2", "url" => download_url }]
      end
      pod_spec_file_path = sanbox_path.join("#{podspec_filename}")
      lg_spec = LgPodPlugin::PodSpec.form_string(podspec_content, pod_spec_file_path)
      unless lg_spec
        File.open(pod_spec_file_path, "w+") do|f|
          f.write podspec_content
        end
        @podspec_content = podspec_content
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2?" + "sha=#{sha}"
        return [{ "filename" => "#{self.name}.tar.bz2", "url" => download_url }]
      end
      self.spec = lg_spec
      @source_files = lg_spec.source_files.keys
      download_params = Array.new
      lg_spec.source_files.each_key do |key|
        next unless trees.include?(key)
        path = LUtils.url_encode(key)
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2#{"\\?"}" + "path#{"\\="}#{path}#{"\\&"}sha#{"\\="}#{sha}"
        download_params.append({"filename" => "#{key}.tar.bz2", "url" => download_url})
      end
      if download_params.empty?
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.tar.bz2?" + "sha=#{sha}"
        return [{ "filename" => "#{self.name}.tar.bz2", "url" => download_url }]
      else
        return download_params
      end
    end

    # 根据branch 下载 zip 包
    def gitlab_download_branch_zip(root_path)
      token = self.config.access_token
      base_url = self.config.project.web_url
      project_name = self.config.project.path
      download_urls = self.gitlab_download_repository_archive_zip(root_path, project_name)
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
      return download_params
    end

    # 通过tag下载zip包
    def gitlab_download_tag_zip(root_path)
      token = self.config.access_token
      base_url = self.config.project.web_url
      project_name = self.config.project.path
      download_urls = self.gitlab_download_repository_archive_zip(root_path, project_name)
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
      return download_params
    end

    # 通过 commit 下载zip包
    def gitlab_download_commit_zip(root_path)
      token = self.config.access_token
      base_url = self.config.project.web_url
      project_name = self.config.project.path
      download_urls = self.gitlab_download_repository_archive_zip(root_path, project_name)
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
      return download_params
    end

  end

end
