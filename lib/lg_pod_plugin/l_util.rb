require  'zip'
module LgPodPlugin
  class LUtils
    def self.unzip_file (zip_file, dest_dir)
      begin
        Zip::File.open(zip_file) do |file|
          file.each do |f|
            file_path = File.join(dest_dir, f.name)
            FileUtils.mkdir_p(File.dirname(file_path))
            next if file_path.include?("Example")
            # next if file_path.include?("LICENSE")
            next if file_path.include?(".gitignore")
            next if file_path.include?("node_modules")
            next if file_path.include?("package.json")
            next if file_path.include?(".swiftlint.yml")
            next if file_path.include?("_Pods.xcodeproj")
            next if file_path.include?("package-lock.json")
            file.extract(f, file_path)
          end
        end
        return true
      rescue => err
        puts err
        return false
      end

    end

    def self.aes_decrypt(key, data)
      de_cipher = OpenSSL::Cipher::Cipher.new("AES-128-CBC")
      de_cipher.decrypt
      de_cipher.key = [key].pack('H*')
      # de_cipher.iv = [iv].pack('H*');
      puts de_cipher.update([data].pack('H*')) << de_cipher.final
    end


  end
end