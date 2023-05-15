require 'json'
# require 'aescrypt'

module  LgPodPlugin

  class Concurrency

    public
    def self.async_download_pods(installers)
      return if installers.empty?
      hash = installers.map(&:download_params).uniq
      json_text = JSON.generate(hash)
      file_path = LFileManager.download_director.join(LUtils.md5(json_text)).to_path + ".json"
      # pp file_path
      File.open(file_path, 'w+') { |f| f.write(json_text) }
      pwd = Pathname.new(File.dirname(__FILE__)).realpath
      FileUtils.chdir pwd
      system("./PodDownload #{file_path}")
      installers.each(&:copy_file_to_caches)
    end

  end
end
