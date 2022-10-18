require 'uri'
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
    def gitlab_download_file_by_name(path, filename, temp_name, project_name)
      host = LRequest.shared.config.host
      project = LRequest.shared.config.project
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
      end
      token = LRequest.shared.config.access_token
      begin
        encode_fiename = LUtils.url_encode(filename)
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.zip#{"\\?"}" + "path#{"\\="}#{encode_fiename}#{"\\&"}sha#{"\\="}#{sha}"
      rescue => exception
        return nil
      end
      LUtils.download_gitlab_zip_file(download_url, token, temp_name)
      return nil unless File.exist?(temp_name)
      result = LUtils.unzip_file(temp_name, "./")
      FileUtils.rm_rf temp_name unless result
      return nil unless result
      temp_zip_folder = nil
      path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        next unless f.to_path.include?("#{filename}") || f.to_path.include?("#{project_name}")
        temp_zip_folder = f
        break
      end
      return nil unless temp_zip_folder && temp_zip_folder.exist?
      begin
        FileUtils.chdir(temp_zip_folder)
        temp_zip_folder.each_child do |f|
          ftype = File::ftype(f)
          FileUtils.mv(f, path)
        end
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
      branch = self.branch ||= "HEAD"
      token = LRequest.shared.config.access_token
      base_url = LRequest.shared.config.project.web_url
      project_name = LRequest.shared.config.project.path
      podspec_name = self.name + ".podspec"
      LgPodPlugin.log_blue "开始下载 => #{base_url}"
      self.gitlab_download_file_by_name(project_path, podspec_name,"#{podspec_name}.zip", project_name)
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
        next if project_path.join(file).exist?
        self.gitlab_download_file_by_name(project_path, file,"#{file}.zip", project_name)
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
      self.gitlab_download_file_by_name(project_path, podspec_name,"#{podspec_name}.zip", project_name)
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
        self.gitlab_download_file_by_name(project_path, file,"#{file}.zip", project_name)
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
      self.gitlab_download_file_by_name(project_path, podspec_name,"#{podspec_name}.zip", project_name)
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
        self.gitlab_download_file_by_name(project_path, file,"#{file}.zip", project_name)
      end
      return project_path
    end

    # 从 Github下载 zip 包
    # 根据branch 下载 zip 包
    def github_download_branch_zip(path, temp_name)
      file_name = "#{temp_name}.zip"
      branch = self.branch ||= "HEAD"
      if self.git.include?(".git")
        base_url = self.git[0...self.git.length - 4]
      else
        base_url = self.git
      end
      project_name = base_url.split("/").last if base_url
      url_path = base_url.split("https://github.com/").last
      if branch == "HEAD"
        download_url = "https://gh.api.99988866.xyz/" + "#{base_url}" + "/archive/#{branch}.zip"
      else
        download_url = "https://codeload.github.com/#{url_path}/zip/refs/heads/#{branch}"
      end
      LgPodPlugin.log_blue "开始下载 => #{download_url}"
      LUtils.download_github_zip_file(download_url, file_name)
      unless File.exist?(file_name)
        LgPodPlugin.log_red("下载zip包失败, 尝试git clone #{self.git}")
        return self.git_clone_by_branch(path, temp_name)
      end
      # 解压文件
      result = LUtils.unzip_file(path.join(file_name).to_path, "./")
      temp_zip_folder = nil
      path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        next unless f.to_path.include?("#{branch}") || f.to_path.include?("#{project_name}")
        temp_zip_folder = f
        break
      end
      unless temp_zip_folder && File.exist?(temp_zip_folder)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_branch(path, temp_name)
      end
      temp_zip_folder
    end

    # 通过tag下载zip包
    def github_download_tag_zip(path, temp_name)
      file_name = "#{temp_name}.zip"
      if self.git.include?(".git")
        base_url = self.git[0...self.git.length - 4]
      else
        base_url = self.git
      end
      uri = URI(base_url)
      project_name = base_url.split("/").last if base_url
      download_url = "https://codeload.github.com#{uri.path}/zip/refs/tags/#{self.tag}"
      # 下载文件
      LgPodPlugin.log_blue "开始下载 => #{download_url}"
      LUtils.download_github_zip_file(download_url, file_name)
      unless File.exist?(file_name)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_tag(path, temp_name)
      end
      # 解压文件
      result = LUtils.unzip_file(path.join(file_name).to_path, "./")
      temp_zip_folder = nil
      path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        version = self.tag.split("v").last ||= self.tag
        next unless f.to_path.include?("#{project_name}") || f.to_path.include?(version)
        temp_zip_folder = f
        break
      end
      unless temp_zip_folder && File.exist?(temp_zip_folder)
        LgPodPlugin.log_red("正在尝试git clone #{self.git}")
        return self.git_clone_by_tag(path, temp_name)
      end
      temp_zip_folder
    end

    # 通过 commit 下载zip包
    def github_download_commit_zip(path, temp_name)
      file_name = "#{temp_name}.zip"
      if self.git.include?(".git")
        base_url = self.git[0...self.git.length - 4]
      else
        base_url = self.git
      end
      uri = URI(base_url)
      project_name = base_url.split("/").last if base_url
      download_url = "https://codeload.github.com#{uri.path}/zip/#{self.commit}"
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

    def git_clone_by_branch(path, temp_name)
      download_temp_path = path.join(temp_name)
      if self.git && self.branch
        git_download_command(temp_name, self.git, self.branch, nil)
      else
        git_download_command(temp_name, self.git, nil, nil)
        if File.exist?(temp_name)
          system("git -C #{download_temp_path.to_path} rev-parse HEAD")
        end
      end
      download_temp_path
    end

    def git_clone_by_tag(path, temp_name)
      git_download_command(temp_name, self.git, nil, self.tag)
      path.join(temp_name)
    end

    # git clone commit
    def git_clone_by_commit(path, temp_name)
      Git.init(temp_name)
      FileUtils.chdir(temp_name)
      LgPodPlugin.log_blue "git clone #{self.git}"
      system("git remote add origin #{self.git}")
      system("git fetch origin #{self.commit}")
      system("git reset --hard FETCH_HEAD")
      path.join(temp_name)
    end

    # 封装 git clone命令
    def git_download_command(temp_name, git, branch, tag)
      cmds = ['git']
      cmds << "clone"
      cmds << "#{git}"
      cmds << "#{temp_name} "
      cmds << "--template="
      cmds << "--single-branch --depth 1"
      if branch
        cmds << "--branch"
        cmds << branch
      elsif tag
        cmds << "--branch"
        cmds << tag
      end
      cmds_to_s = cmds.join(" ")
      LgPodPlugin.log_blue cmds_to_s
      system(cmds_to_s)
    end

  end

end