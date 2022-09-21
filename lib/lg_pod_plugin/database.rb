# require "sqlite3"
# require 'singleton'
# require_relative 'l_cache'
#
# module LgPodPlugin
#
#   class LSqliteDb
#     include Singleton
#     REQUIRED_ATTRS ||= %i[db table_name].freeze
#     attr_accessor(*REQUIRED_ATTRS)
#     # 初始化 db
#     def initialize
#       root_path = LFileManager.download_director.join("database")
#       db_file_path = root_path.join("my.db")
#       if !root_path.exist? || !db_file_path.exist?
#         FileUtils.mkdir(root_path)
#         FileUtils.chdir(root_path)
#         FileUtils.touch("my.db")
#       end
#       # FileUtils.chdir(root_path)
#       self.db = SQLite3::Database.new(db_file_path.to_path)
#       #添加表
#       # sql = "create table IF NOT EXISTS LgPodTable (id integer primary key autoincrement not null, name varchar(100), branch varchar(100), commit varchar(100));"
#       sql = "create table if not exists lg_pod_table(
#         id integer primary key autoincrement not null,
#         name varchar(100),
# 	      branch varchar(100),
# 	      sha varchar(100),
#         tag varchar(100),
#         local_path varchar(150),
#         update_time TimeStamp NOT NULL DEFAULT CURRENT_TIMESTAMP)"
#       self.db.execute(sql)
#       self.table_name = "lg_pod_table"
#       super
#     end
#
#     def insert_table(name, branch, sha, tag, path)
#       timestamp = Time.now.to_i * 1000
#       pod_info = self.select_table(name, branch)
#       if pod_info.name
#         self.db.execute_batch(
#           "UPDATE #{table_name} SET sha = (:sha), tag = (:tag), local_path = (:local_path), update_time = (:update_time) where (name = :name) and (branch = :branch)", {"branch" => branch,"name" => name, "sha" => sha,"tag" => tag, :update_time => timestamp, :local_path => path.to_path}
#         )
#       else
#         self.db.execute("INSERT INTO #{table_name} (name, branch, sha, tag, local_path, update_time)
#             VALUES (?, ?, ?, ?,?,?)", [name, branch, sha, tag, path.to_path, timestamp])
#       end
#     end
#
#     def should_clean_pod_info(name, branch)
#       current_pod = self.select_table(name, branch)
#       if current_pod&.path && !Dir.exist?(current_pod.path)
#         self.delete_table(current_pod.name, current_pod.branch)
#       end
#       array = self.select_tables(name, branch)
#       if array.count <= 2
#         return
#       end
#
#       #待删除的 pod 换成
#       pod_info = array.first
#       if pod_info&.path && Dir.exist?(pod_info.path)
#         FileUtils.rm_rf(pod_info.path)
#         self.delete_table(pod_info.name, pod_info.branch)
#         array.delete(pod_info)
#       end
#
#     end
#
#     def select_table(name, branch)
#       pod_info = LCachePodInfo.new
#       self.db.execute( "select * from #{self.table_name} where name = '#{name}' and branch = '#{branch}'; ") do |row|
#         pod_info.name = row[1]
#         pod_info.branch = row[2]
#         pod_info.sha = row[3]
#         pod_info.tag = row[4]
#         pod_info.path = row[5]
#         pod_info.timestamp = row[6]
#       end
#       pod_info
#     end
#
#     def select_tables(name, branch)
#       array = []
#       self.db.execute( "select * from #{self.table_name} where name = '#{name}' and branch != '#{branch}' order by update_time;") do |row|
#         pod_info = LCachePodInfo.new
#         pod_info.name = row[1]
#         pod_info.branch = row[2]
#         pod_info.sha = row[3]
#         pod_info.tag = row[4]
#         pod_info.path = row[5]
#         pod_info.timestamp = row[6]
#         array.append(pod_info)
#       end
#       array
#     end
#
#     def delete_table(name, branch)
#       self.db.execute("delete from #{self.table_name} where name = ? and branch = ? ;", [name, branch])
#     end
#
#   end
#
# end