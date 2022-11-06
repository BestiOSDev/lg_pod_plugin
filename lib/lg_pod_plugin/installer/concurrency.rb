require 'json'
require 'aescrypt'

module  LgPodPlugin

  class Concurrency

    public
    def self.async_download_pods(installers)
      return if installers.empty?
      json_text = installers.map(&:download_params).uniq.to_json
      arvg = LUtils.encrypt json_text, "AZMpxzVxzbo3sFDLRZMpxzVxzbo3sFDZ"
      return unless arvg && !arvg.empty?
      pwd = Pathname.new(File.dirname(__FILE__)).realpath
      FileUtils.chdir pwd
      system("./PodDownload #{arvg}")
      installers.each(&:copy_file_to_caches)
    end

  end
end
