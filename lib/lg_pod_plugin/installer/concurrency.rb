require 'json'
require 'aescrypt'

module  LgPodPlugin

  class Concurrency

    def self.async_download_pods(installers)
      return if installers.empty?
      download_params = installers.map do |ins|
        ins.send(:download_params)
      end
      text = JSON.generate download_params ||= ""
      arvg = LUtils.encrypt text, "AZMpxzVxzbo3sFDLRZMpxzVxzbo3sFDZ"
      return unless arvg && !arvg.empty?
      pwd = Pathname.new(File.dirname(__FILE__)).realpath
      FileUtils.chdir pwd
      system("./PodDownload #{arvg}")
      installers.each(&:copy_file_to_caches)
    end

  end
end
