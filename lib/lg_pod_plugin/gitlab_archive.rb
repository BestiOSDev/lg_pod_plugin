
require 'uri'
require 'net/http'
require_relative 'request'
require_relative 'l_util'
require_relative 'l_config'
require_relative 'podspec'
require_relative 'gitlab_api'

module LgPodPlugin

  class GitLabArchive
    REQUIRED_ATTRS ||= %i[git tag name commit branch].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(name, git, branch, tag, commit)
      self.git = git ||= LRequest.shared.request_params[:git]
      self.tag = tag ||= LRequest.shared.request_params[:tag]
      self.name = name ||= LRequest.shared.request_params[:name]
      self.commit = commit ||= LRequest.shared.request_params[:commit]
      self.branch = branch ||= LRequest.shared.request_params[:branch]
    end

    # 下载某个文件zip格式
    def gitlab_download_file_by_name(path,filename, temp_name)
      host = LRequest.shared.config.host
      project = LRequest.shared.config.project
      unless host
        uri = URI(project.web_url)
        host = uri.scheme + "://" + uri.hostname
        ip_address = LUtils.git_server_ip_address(host)
        if ip_address == nil
          return
        end
      end

      if self.git && self.tag
        sha = self.tag
      elsif self.git && self.branch
        sha = self.branch
      elsif self.git && self.commit
        sha = self.commit
      end
      token = LRequest.shared.config.access_token
      begin
        encode_fiename = LUtils.url_encode(filename)
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.zip?" + "path=#{encode_fiename}&&sha=#{sha}"
      rescue => exception
        return nil
      end
      LUtils.download_gitlab_zip_file(download_url, token, temp_name)
      return nil unless File.exist?(temp_name)
      return nil unless (result = LUtils.unzip_file(temp_name, "./"))
      temp_zip_folder = nil
      path.each_child do |f|
        next unless f.to_path.include?("-#{filename}")
        temp_zip_folder = f
      end
      return nil unless temp_zip_folder && temp_zip_folder.exist?
      begin
        FileUtils.chdir(temp_zip_folder)
        real_file_path = temp_zip_folder.join(filename)
        FileUtils.mv(real_file_path, path)
        FileUtils.chdir(path)
        FileUtils.rm_rf(temp_zip_folder)
        FileUtils.rm_rf("./#{temp_name}")
        return path
      rescue => exception
        pp exception
        return path
      end
    end

    # 从 GitLab下载 zip包
    # 根据branch 下载 zip 包
    def gitlab_download_branch_zip(root_path, temp_name)
      project_path = root_path.join(self.name)
      unless project_path.exist?
        project_path.mkdir
        FileUtils.chdir(project_path)
      end
      branch = self.branch ||= "master"
      token = LRequest.shared.config.access_token
      base_url = LRequest.shared.config.project.web_url
      project_name = LRequest.shared.config.project.path
      podspec_name = self.name + ".podspec"
      LgPodPlugin.log_blue "开始下载 => #{base_url}"
      self.gitlab_download_file_by_name(project_path, podspec_name,"#{podspec_name}.zip")
      podspec_path = project_path.join(podspec_name)
      return nil unless File.exist?(podspec_path)
      begin
        need_download_files = PodSpec.form_file(podspec_path).source_files
      rescue
        need_download_files = Set[]
      end
      unless !need_download_files.empty?
        FileUtils.chdir(root_path)
        file_name = "#{temp_name}.zip"
        download_url = LUtils.get_gitlab_download_url(base_url, branch, nil, nil, project_name)
        raise "download_url不存在" unless download_url
        # LgPodPlugin.log_blue "开始下载 => #{download_url}"
        LUtils.download_gitlab_zip_file(download_url, token, file_name)
        raise "下载zip包失败, 尝试git clone #{self.git}" unless File.exist?(file_name)
        # 解压文件
        result = LUtils.unzip_file(root_path.join(file_name).to_path, "./")
        new_file_name = "#{project_name}-#{branch}"
        raise "解压文件失败, #{new_file_name}不存在" unless result && File.exist?(new_file_name)
        return root_path.join(new_file_name)
      end
      need_download_files.each do |file|
        self.gitlab_download_file_by_name(project_path, file,"#{file}.zip")
      end
      return project_path
    end

    # 通过tag下载zip包
    def gitlab_download_tag_zip(root_path, temp_name)
      project_path = root_path.join(self.name)
      unless project_path.exist?
        project_path.mkdir
        FileUtils.chdir(project_path)
      end
      token = LRequest.shared.config.access_token
      base_url = LRequest.shared.config.project.web_url
      project_name = LRequest.shared.config.project.path
      podspec_name = self.name + ".podspec"
      LgPodPlugin.log_blue "开始下载 => #{base_url}"
      self.gitlab_download_file_by_name(project_path, podspec_name,"#{podspec_name}.zip")
      podspec_path = project_path.join(podspec_name)
      return nil unless File.exist?(podspec_path)
      begin
        need_download_files = PodSpec.form_file(podspec_path).source_files
      rescue
        need_download_files = Set[]
      end
      unless !need_download_files.empty?
        tag = self.tag
        FileUtils.chdir(root_path)
        file_name = "#{temp_name}.zip"
        download_url = LUtils.get_gitlab_download_url(base_url, nil, tag, nil, project_name)
        raise "download_url不存在" unless download_url
        LUtils.download_gitlab_zip_file(download_url, token, file_name)
        raise "下载zip包失败, 尝试git clone #{self.git}" unless File.exist?(file_name)
        # 解压文件
        result = LUtils.unzip_file(root_path.join(file_name).to_path, "./")
        new_file_name = "#{project_name}-#{tag}"
        raise "解压文件失败, #{new_file_name}不存在" unless result && File.exist?(new_file_name)
        return root_path.join(new_file_name)
      end
      need_download_files.each do |file|
        self.gitlab_download_file_by_name(project_path, file,"#{file}.zip")
      end
      return project_path
    end

    # 通过 commit 下载zip包
    def gitlab_download_commit_zip(root_path, temp_name)
      project_path = root_path.join(self.name)
      unless project_path.exist?
        project_path.mkdir
        FileUtils.chdir(project_path)
      end
      token = LRequest.shared.config.access_token
      base_url = LRequest.shared.config.project.web_url
      project_name = LRequest.shared.config.project.path
      podspec_name = self.name + ".podspec"
      LgPodPlugin.log_blue "开始下载 => #{base_url}"
      self.gitlab_download_file_by_name(project_path, podspec_name,"#{podspec_name}.zip")
      podspec_path = project_path.join(podspec_name)
      return nil unless File.exist?(podspec_path)
      begin
        need_download_files = PodSpec.form_file(podspec_path).source_files
      rescue
        need_download_files = Set[]
      end
      unless !need_download_files.empty?
        FileUtils.chdir(root_path)
        file_name = "#{temp_name}.zip"
        download_url = LUtils.get_gitlab_download_url(base_url, nil, nil, self.commit, project_name)
        raise "download_url不存在" unless download_url
        # LgPodPlugin.log_blue "开始下载 => #{download_url}"
        LUtils.download_gitlab_zip_file(download_url, token, file_name)
        raise "下载zip包失败, 尝试git clone #{self.git}" unless File.exist?(file_name)
        # 解压文件
        result = LUtils.unzip_file(root_path.join(file_name).to_path, "./")
        new_file_name = "#{project_name}-#{self.commit}"
        raise "解压文件失败, #{new_file_name}不存在" unless result && File.exist?(new_file_name)
        return root_path.join(new_file_name)
      end
      need_download_files.each do |file|
        self.gitlab_download_file_by_name(project_path, file,"#{file}.zip")
      end
      return project_path
    end

    # 从 Github下载 zip 包
    # 根据branch 下载 zip 包
    def github_download_branch_zip(path, temp_name)
      file_name = "#{temp_name}.zip"
      branch = self.branch ||= "master"
      if self.git.include?(".git")
        base_url = self.git[0...self.git.length - 4]
      else
        base_url = self.git
      end
      origin_url = base_url + "/archive/#{branch}.zip"
      project_name = base_url.split("/").last if base_url
      download_url = "https://gh.api.99988866.xyz/#{origin_url}"
      LgPodPlugin.log_blue "开始下载 => #{download_url}"
      LUtils.download_github_zip_file(download_url, file_name)
      unless File.exist?(file_name)
        LgPodPlugin.log_red("下载zip包失败, 尝试git clone #{self.git}")
        return self.git_clone_by_branch(path, temp_name)
      end
      # 解压文件
      result = LUtils.unzip_file(path.join(file_name).to_path, "./")
      new_file_name = "#{project_name}-#{branch}"
      unless result && File.exist?(new_file_name)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_branch(path, temp_name)
      end
      path.join(new_file_name)
    end

    # 通过tag下载zip包
    def github_download_tag_zip(path, temp_name)
      file_name = "#{temp_name}.zip"
      if self.git.include?(".git")
        base_url = self.git[0...self.git.length - 4]
      else
        base_url = self.git
      end
      project_name = base_url.split("/").last if base_url
      origin_url = base_url + "/archive/refs/tags/#{self.tag}.zip"
      download_url = "https://gh.api.99988866.xyz/#{origin_url}"
      # 下载文件
      LgPodPlugin.log_blue "开始下载 => #{download_url}"
      LUtils.download_github_zip_file(download_url, file_name)
      unless File.exist?(file_name)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_tag(path, temp_name)
      end
      # 解压文件
      result = LUtils.unzip_file(path.join(file_name).to_path, "./")
      if self.tag.include?("v") && self.tag[0...1] == "v"
        this_tag = self.tag[1...self.tag.length]
      else
        this_tag = self.tag
      end
      new_file_name = "#{project_name}-#{this_tag}"
      unless result && File.exist?(new_file_name)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_tag(path, temp_name)
      end
      path.join(new_file_name)
    end

    # 通过 commit 下载zip包
    def github_download_commit_zip(path, temp_name)
      file_name = "#{temp_name}.zip"
      if self.git.include?(".git")
        base_url = self.git[0...self.git.length - 4]
      else
        base_url = self.git
      end
      project_name = base_url.split("/").last if base_url
      origin_url = base_url + "/archive/#{self.commit}.zip"
      download_url = "https://gh.api.99988866.xyz/#{origin_url}"
      # 下载文件
      LgPodPlugin.log_blue "开始下载 => #{download_url}"
      LUtils.download_github_zip_file(download_url, file_name)
      unless File.exist?(file_name)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_commit(path, temp_name)
      end
      # 解压文件
      result = LUtils.unzip_file(path.join(file_name).to_path, "./")
      new_file_name = "#{project_name}-#{self.commit}"
      unless result && File.exist?(new_file_name)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_commit(path, temp_name)
      end
      path.join(new_file_name)
    end

  end

end