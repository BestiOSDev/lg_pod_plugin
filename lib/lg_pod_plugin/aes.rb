require 'openssl'

module LgPodPlugin

  def self.aes_dicrypt(key, data)
    de_cipher = OpenSSL::Cipher::Cipher.new("AES-128-CBC");
    de_cipher.decrypt;
    de_cipher.key = [key].pack('H*')
    # de_cipher.iv = [iv].pack('H*');
    puts de_cipher.update([data].pack('H*')) << de_cipher.final;
  end

end