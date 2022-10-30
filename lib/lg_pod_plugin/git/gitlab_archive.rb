require 'uri'
require_relative '../uitils/l_util'
module LgPodPlugin

  class GitLabArchive
    REQUIRED_ATTRS ||= %i[git tag name commit branch config].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(name, git, branch, tag, commit, config)
      self.git = git
      self.tag = tag
      self.name = name
      self.config = config
      self.commit = commit
      self.branch = branch
    end

    # 下载某个文件zip格式
    def gitlab_download_repository_archive_zip(path, temp_name, project_name, async = true)
      host = self.config.host
      filename = temp_name + ".zip"
      project = self.config.project
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
      token = self.config.access_token
      begin
        download_url = host + "/api/v4/projects/" + "#{project.id}" + "/repository/archive.zip?" + "sha=#{sha}"
        return LUtils.download_gitlab_zip_file(path, token, download_url, filename, async)
      rescue => exception
        return nil
      end
    end

    # 根据branch 下载 zip 包
    def gitlab_download_branch_zip(root_path, temp_name, branch = nil, async = true)
      new_branch = branch ? branch : "HEAD"
      token = self.config.access_token
      base_url = self.config.project.web_url
      project_name = self.config.project.path
      # LgPodPlugin.log_blue "开始下载 => #{base_url}"
      hash_map = self.gitlab_download_repository_archive_zip(root_path, temp_name, project_name, async)
      if hash_map && hash_map.is_a?(Hash)
        hash_map["type"] = "gitlab-branch"
        return hash_map
      end
      raise "下载文件失败" unless hash_map && File.exist?(hash_map)
      raise "解压文件失败" unless LUtils.unzip_file(hash_map.to_path, "./")
      temp_zip_folder = nil
      root_path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        next unless f.to_path.include?("#{new_branch}") || f.to_path.include?("#{project_name}")
        temp_zip_folder = f
        break
      end
      if temp_zip_folder&.exist?
        return temp_zip_folder
      else
        raise "下载文件失败"
      end
    end

    # 通过tag下载zip包
    def gitlab_download_tag_zip(root_path, temp_name, async = true)
      token = self.config.access_token
      base_url = self.config.project.web_url
      project_name = self.config.project.path
      hash_map = self.gitlab_download_repository_archive_zip(root_path, temp_name, project_name, async)
      if hash_map && hash_map.is_a?(Hash)
        hash_map["type"] = "gitlab-tag"
        return hash_map
      end
      raise "下载文件失败" unless hash_map && File.exist?(hash_map)
      raise "解压文件失败" unless LUtils.unzip_file(hash_map.to_path, "./")
      temp_zip_folder = nil
      root_path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        next unless f.to_path.include?("#{self.tag}") || f.to_path.include?("#{project_name}")
        temp_zip_folder = f
        break
      end
      if temp_zip_folder&.exist?
        return temp_zip_folder
      else
        raise "下载文件失败"
      end
    end

    # 通过 commit 下载zip包
    def gitlab_download_commit_zip(root_path, temp_name, async = true)
      token = self.config.access_token
      base_url = self.config.project.web_url
      project_name = self.config.project.path
      # LgPodPlugin.log_blue "开始下载 => #{base_url}"
      hash_map = self.gitlab_download_repository_archive_zip(root_path, temp_name, project_name, async)
      if hash_map && hash_map.is_a?(Hash)
        hash_map["type"] = "gitlab-commit"
        return hash_map
      end
      raise "下载文件失败" unless hash_map && File.exist?(hash_map)
      raise "解压文件失败" unless LUtils.unzip_file(hash_map.to_path, "./")
      temp_zip_folder = nil
      root_path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        next unless f.to_path.include?("#{self.commit}") || f.to_path.include?("#{project_name}")
        temp_zip_folder = f
        break
      end
      if temp_zip_folder&.exist?
        return temp_zip_folder
      else
        raise "下载文件失败"
      end
    end

    # 从 Github下载 zip 包
    # 根据branch 下载 zip 包
    def github_download_branch_zip(path, temp_name, branch = nil, async = true)
      file_name = "#{temp_name}.zip"
      new_branch = branch ? branch : "HEAD"
      if self.git.include?(".git")
        base_url = self.git[0...self.git.length - 4]
      else
        base_url = self.git
      end
      project_name = base_url.split("/").last if base_url
      url_path = base_url.split("https://github.com/").last
      if new_branch == "HEAD"
        download_url = "https://gh.api.99988866.xyz/" + "#{base_url}" + "/archive/#{new_branch}.zip"
      else
        download_url = "https://codeload.github.com/#{url_path}/zip/refs/heads/#{new_branch}"
      end
      hash_map = LUtils.download_github_zip_file(path, download_url, file_name, async)
      if hash_map && hash_map.is_a?(Hash)
        hash_map["type"] = "github-branch"
        return hash_map
      end
      raise "下载文件失败" unless File.exist?(hash_map)
      # 解压文件
      raise "解压文件失败" unless LUtils.unzip_file(hash_map.to_path, "./")
      temp_zip_folder = nil
      path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        next unless f.to_path.include?("#{new_branch}") || f.to_path.include?("#{project_name}")
        temp_zip_folder = f
        break
      end
      if temp_zip_folder&.exist?
        return temp_zip_folder
      else
        raise "下载文件失败"
      end
    end

    # 通过tag下载zip包
    def github_download_tag_zip(path, temp_name, async = true)
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
      hash_map = LUtils.download_github_zip_file(path, download_url, file_name, async)
      if hash_map && hash_map.is_a?(Hash)
        hash_map["type"] = "github-tag"
        return hash_map
      end
      raise "下载文件失败" unless File.exist?(hash_map)
      # 解压文件
      raise "解压文件失败" unless LUtils.unzip_file(hash_map.to_path, "./")
      temp_zip_folder = nil
      path.each_child do |f|
        ftype = File::ftype(f)
        next unless ftype == "directory"
        version = self.tag.split("v").last ||= self.tag
        next unless f.to_path.include?("#{project_name}") || f.to_path.include?(version)
        temp_zip_folder = f
        break
      end
      if temp_zip_folder&.exist?
        return temp_zip_folder
      else
        raise "下载文件失败"
      end
    end

    # 通过 commit 下载zip包
    def github_download_commit_zip(path, temp_name, async = true)
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
      hash_map = LUtils.download_github_zip_file(path, download_url, file_name, async)
      if hash_map && hash_map.is_a?(Hash)
        hash_map["type"] = "github-commit"
        return hash_map
      end
      raise "下载文件失败" unless File.exist?(hash_map)
      # 解压文件
      raise "解压文件失败" unless LUtils.unzip_file(hash_map.to_path, "./")
      new_file_name = "#{project_name}-#{self.commit}"
      if File.exist?(new_file_name)
        return path.join(new_file_name)
      else
        raise "下载文件失败"
      end
    end

    def git_clone_by_branch(path, temp_name, branch = nil)
      new_branch = branch ? branch : nil
      download_temp_path = path.join(temp_name)
      if self.git && new_branch
        git_download_command(temp_name, self.git, new_branch, nil)
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

    # 根据参数生成下载 url
    def get_gitlab_download_url(base_url, branch, tag, commit, project_name)
      if base_url.include?("http:") || base_url.include?("https:")
        if branch
          return base_url + "/-/archive/" + branch + "/#{project_name}-#{branch}.zip"
        elsif tag
          return base_url + "/-/archive/" + tag + "/#{project_name}-#{tag}.zip"
        elsif commit
          return base_url + "/-/archive/" + commit + "/#{project_name}-#{commit}.zip"
        else
          return nil
        end
      end
      return nil unless base_url.include?("ssh://git@gitlab") || base_url.include?("git@")
      project = self.config.project
      if project && project.web_url && project.web_url.include?("http")
        get_gitlab_download_url(project.web_url, branch, tag, commit, project_name)
      else
        nil
      end
    end

  end

end
