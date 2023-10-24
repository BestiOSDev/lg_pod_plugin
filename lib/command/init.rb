require 'claide'
require 'json'
require_relative 'command'

module LgPodPlugin
  class Command
    class Init < Command
      self.command = "init"
      self.abstract_command = false
      self.summary = '初始化gitlab projects 信息'
      attr_accessor :token
      attr_accessor :host
      self.description = <<-DESC
        Manipulate the download cache for pods, like printing the cache content
        or cleaning the pods cache.
      DESC

      def initialize(argv)
        self.host = argv.option('host')
        self.token = argv.option('token')
        super
      end

      def run
        if self.host.nil? || self.host == ""
          LgPodPlugin.log_red  "传入host不能为空"
          return
        end
        if self.token.nil? || self.token == ""
          LgPodPlugin.log_red "传入token不能为空"
          return
        end
        token_vaild = GitLabAPI.request_user_emails(self.host, self.token)
        if token_vaild == "invalid token"
          LgPodPlugin.log_red "无效的access_token, 请检查私人令牌是否在有限期内"
          return
        end
        refresh_token = ""
        expires_in = 7879680
        created_at = Time.now.to_i
        encrypt_access_token = LUtils.encrypt(self.token, "AZMpxzVxzbo3sFDLRZMpxzVxzbo3sFDZ")
        hash = {"access_token": encrypt_access_token}
        hash["token_type"] = "Bearer"
        hash["expires_in"] = expires_in
        hash["scope"] = "api"
        hash["created_at"] = created_at
        hash["refresh_token"] = refresh_token
        db_path = LFileManager.download_director.join("database")
        db_path.mkdir unless db_path.exist?
        token_file = db_path.join("access_token.json")
        str = JSON.generate(hash)
        File.open(token_file.to_path, 'w+') { |f| f.write(str) }
        LSqliteDb.shared.init_database
        user_id = LUserAuthInfo.get_user_id(self.host)
        user_model = LUserAuthInfo.new(user_id, "", "", self.host, self.token, "", (created_at + expires_in), created_at, 1)
        LSqliteDb.shared.insert_user_info(user_model)
        LgPodPlugin.log_green "设置私人访问令牌成功"
      end

    end
  end
end
