require 'uri'
require_relative '../utils/l_util'

module LgPodPlugin

  class GitRepository
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
        self.git_clone_by_tag(self.path, "lg_temp_pod")
      elsif self.git && self.branch
        self.git_clone_by_branch self.path, "lg_temp_pod", self.branch
      elsif self.git && self.commit
        self.git_clone_by_commit self.path, "lg_temp_pod"
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

  end

end
