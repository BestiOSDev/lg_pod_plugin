require 'singleton'
require 'sqlite3'

module LgPodPlugin

  class ProjectModel
    REQUIRED_ATTRS ||= %i[id name path description ssh_url_to_repo http_url_to_repo web_url path_with_namespace name_with_namespace].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(id = nil, name = nil, description = nil, path = nil, ssh_url_to_repo = nil, http_url_to_repo = nil, web_url = nil, name_with_namespace = nil, path_with_namespace = nil)
      self.id = id
      self.path = path
      self.name = name
      self.web_url = web_url
      self.description = description
      self.ssh_url_to_repo = ssh_url_to_repo
      self.http_url_to_repo = http_url_to_repo
      self.path_with_namespace = path_with_namespace
      self.name_with_namespace = name_with_namespace
    end

  end

  class LUserAuthInfo
    REQUIRED_ATTRS ||= %i[id username password host access_token refresh_token expires_in update_time type].freeze
    attr_accessor(*REQUIRED_ATTRS)

    def initialize(id = nil, name = nil, pwd = nil, host = nil, token = nil, refresh_token = nil, time = nil, update_time = nil, type = 0)
      self.id = id
      self.type = type
      self.host = host
      self.password = pwd
      self.username = name
      self.expires_in = time
      self.access_token = token
      self.update_time = update_time
      self.refresh_token = refresh_token
    end

    # 创建一个userId
    def self.get_user_id(host)
      body = host + Dir.home
      return Digest::MD5.hexdigest(body)
    end

  end

  class LSqliteDb
    include Singleton
    REQUIRED_ATTRS ||= %i[db].freeze
    attr_accessor(*REQUIRED_ATTRS)
    K_USER_TABLE = "user_tab"
    K_USER_PROJECTS = "user_projects"
    K_POD_LATEST_REFS = "user_pod_latest_refs"
    K_POD_SHA_BRANCH = "user_pod_sha_with_branch"

    def self.shared
      return LSqliteDb.instance
    end

    # 初始化 db
    def initialize
    end

    #初始化database
    def init_database
      root_path = LFileManager.download_director.join("database")
      db_file_path = root_path.join("my.db")
      unless root_path.exist? && db_file_path.exist?
        FileUtils.mkdir(root_path)
        FileUtils.chdir(root_path)
        FileUtils.touch("my.db")
      end
      # FileUtils.chdir(root_path)
      self.db = SQLite3::Database.new(db_file_path.to_path)
      #添加用户表
      sql1 = "create table if not exists #{K_USER_TABLE}(
        id varchar(100) primary key not null,
        username varchar(100),
	      password varchar(100),
	      host varchar(100),
        access_token varchar(100),
        refresh_token varchar(100),
        expires_in TimeStamp NOT NULL DEFAULT CURRENT_TIMESTAMP);"
      self.db.execute(sql1)

      sel_sql = "select * from sqlite_master where name = '#{K_USER_TABLE}' and sql like '%update_time%'; "
      resultSetPrincipal = self.db.execute(sel_sql)
      if resultSetPrincipal.count == 0
        alter = "ALTER TABLE #{K_USER_TABLE}  ADD 'update_time' TimeStamp;"
        self.db.execute(alter)
      end

      user_sel_sql2 = "select * from sqlite_master where name = '#{K_USER_TABLE}' and sql like '%type%'; "
      resultSetPrincipal2 = self.db.execute(user_sel_sql2)
      if resultSetPrincipal2.count == 0
        alter = "ALTER TABLE #{K_USER_TABLE}  ADD 'type' INT;"
        self.db.execute(alter)
      end

      #添加项目表
      sql2 = "create table if not exists #{K_USER_PROJECTS}(
        id varchar(100) primary key not null,
        name varchar(100),
	      desc varchar(100),
	      path varchar(100),
        ssh_url_to_repo varchar(100),
        http_url_to_repo varchar(100),
        web_url varchar(100),
        name_with_namespace varchar(100),
        path_with_namespace varchar(100)
       );"
      self.db.execute(sql2)

    end

    public
    def insert_user_info(user)
      # pp "user.id => #{user.id}"
      if self.query_user_info(user.id) != nil
        self.db.execute_batch(
          "UPDATE #{K_USER_TABLE} SET username = (:username), password = (:password), host = (:host), access_token = (:access_token), expires_in = (:expires_in), refresh_token = (:refresh_token), update_time = (:update_time), type = (:type) where (id = :id)", { "username" => user.username, "password" => user.password, "host" => user.host, "access_token" => user.access_token, :expires_in => user.expires_in, :id => user.id, :refresh_token => user.refresh_token , :update_time => user.update_time, :type => user.type}
        )
      else
        self.db.execute("INSERT INTO #{K_USER_TABLE} (id, username, password, host, access_token,refresh_token, expires_in, update_time, type)
            VALUES (?, ?, ?, ?,?,?,?, ?, ?)", [user.id, user.username, user.password, user.host, user.access_token, user.refresh_token, user.expires_in, user.update_time, user.type])
      end

    end

    public

    def query_user_info(user_id)
      user_info = nil
      self.db.execute("select * from #{K_USER_TABLE} where id = '#{user_id}';") do |row|
        user_info = LUserAuthInfo.new
        user_info.id = row[0]
        user_info.username = row[1]
        user_info.password = row[2]
        user_info.host = row[3]
        user_info.access_token = row[4]
        user_info.refresh_token = row[5]
        user_info.expires_in = row[6]
        user_info.update_time = row[7]
        user_info.type = row[8]
      end
      user_info
    end

    #删除用户信息
    def delete_user_info(id)
      ps = @db.prepare("DELETE FROM #{K_USER_TABLE} WHERE id = :n")
      ps.execute('n' => id)
    end

    # 保存项目信息到数据库
    def insert_project(project)
      if self.query_project_info(project.name, project.http_url_to_repo) != nil
        self.db.execute_batch(
          "UPDATE #{K_USER_PROJECTS} SET name = (:name), desc = (:desc), path = (:path), ssh_url_to_repo = (:ssh_url_to_repo), http_url_to_repo = (:http_url_to_repo), web_url = (:web_url), name_with_namespace = (:name_with_namespace), path_with_namespace = (:path_with_namespace) where (id = :id)", { "name" => project.name, "desc" => project.description, "path" => project.path, "ssh_url_to_repo" => project.ssh_url_to_repo, :http_url_to_repo => project.http_url_to_repo, :web_url => project.web_url, :id => project.id, :path_with_namespace => project.path_with_namespace, :name_with_namespace => project.name_with_namespace }
        )
      else
        self.db.execute("INSERT INTO #{K_USER_PROJECTS} (id, name, desc, path, ssh_url_to_repo, http_url_to_repo, web_url,name_with_namespace, path_with_namespace)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", [project.id, project.name, project.description, project.path, project.ssh_url_to_repo, project.http_url_to_repo, project.web_url, project.name_with_namespace, project.path_with_namespace])
      end
    end

    # 通过名称查询项目信息
    def query_project_info(name, git)
      project_info = nil
      self.db.execute("select * from #{K_USER_PROJECTS} where name = '#{name}' or path = '#{name}' ;") do |row|
        name_with_namespace = row[7]
        path_with_namespace = row[8]
        next unless git.include?(name_with_namespace) || git.include?(path_with_namespace)
        id = row[0]
        path = row[3]
        name = row[1]
        web_url = row[6]
        description = row[2]
        ssh_url_to_repo = row[4]
        http_url_to_repo = row[5]
        project_info = ProjectModel.new(id, name, description, path, ssh_url_to_repo, http_url_to_repo, web_url, name_with_namespace, path_with_namespace)
        return project_info
      end
      project_info
    end

    def delete_project_by_id(project_id)
      ps = @db.prepare("DELETE FROM #{K_USER_PROJECTS} WHERE id = :n")
      ps.execute('n' => project_id)
    end

    # def insert_pod_refs(name, git, branch, tag, commit)
    #   id = LPodLatestRefs.get_pod_id(name, git, branch)
    #   pod = LPodLatestRefs.new(id, name, git, branch, tag, commit)
    #   if self.query_pod_refs(id) != nil
    #     self.db.execute_batch(
    #       "UPDATE #{K_POD_LATEST_REFS} SET name = (:name), git = (:git), branch = (:branch), tag = (:tag), sha = (:sha) where (id = :id)", { "name" => pod.name, "git" => pod.git, "sha" => pod.commit, "branch" => pod.branch, :tag => pod.tag, :id => pod.id }
    #     )
    #   else
    #     self.db.execute("INSERT INTO #{K_POD_LATEST_REFS} (id, name, git, branch, tag, sha)
    #         VALUES (?, ?, ?, ?, ?, ?)", [pod.id, pod.name, pod.git, pod.branch, pod.tag, pod.commit])
    #   end
    #   self.insert_pod_sha_with_branch(name, git, commit, branch)
    # end
    #
    # def query_pod_refs(id)
    #   pod_info = nil
    #   self.db.execute("select * from #{K_POD_LATEST_REFS} where id = '#{id}';") do |row|
    #     id = row[0]
    #     name = row[1]
    #     git = row[2]
    #     branch = row[3]
    #     tag = row[4]
    #     commit = row[5]
    #     pod_info = LPodLatestRefs.new(id, name, git, branch, tag, commit)
    #   end
    #   pod_info
    # end

    # 保存 sha, branch 到数据库
    # def insert_pod_sha_with_branch(name, git, sha, branch)
    #   return unless name && git && sha
    #   id = Digest::MD5.hexdigest(name + git + sha)
    #   if self.query_branch_with_sha(name, git, sha)[:sha] != nil
    #     self.db.execute_batch(
    #       "UPDATE #{K_POD_SHA_BRANCH} SET name = (:name), git = (:git), branch = (:branch), sha = (:sha) where (id = :id)", { "name" => name, "git" => git, "branch" => branch, :id => id, :sha => sha }
    #     )
    #   else
    #     self.db.execute("INSERT INTO #{K_POD_SHA_BRANCH} (id, name, git, branch, sha)
    #         VALUES (?, ?, ?, ?, ?)", [id, name, git, branch, sha])
    #   end
    # end

    # 通过 sha 查询对应 branch
  #   def query_branch_with_sha(id = nil, name, git, sha)
  #     hash_map = Hash.new
  #     id = Digest::MD5.hexdigest(name + git + sha) unless id
  #     self.db.execute("select * from #{K_POD_SHA_BRANCH} where id = '#{id}' and name = '#{name}' and git = '#{git}' ;") do |row|
  #       new_id = row[0]
  #       new_sha = row[4]
  #       new_git = row[2]
  #       new_name = row[1]
  #       new_branch = row[3]
  #       hash_map[:id] = new_id
  #       hash_map[:git] = new_git
  #       hash_map[:sha] = new_sha
  #       hash_map[:name] = new_name
  #       hash_map[:branch] = new_branch
  #     end
  #     hash_map
  #   end
  #
  end

end
