module Nagios::Promoo::Utils
  module Cache
    CACHE_DIR = '/tmp/nagios-promoo_cache'

    def cache_fetch(key, expiration = 3600)
      fail 'You have to provide a block!' unless block_given?
      FileUtils.mkdir_p CACHE_DIR
      filename = File.join(CACHE_DIR, key)

      if cache_valid?(filename, expiration)
        File.open(filename, 'r') { |file|
          file.flock(File::LOCK_SH)
          JSON.parse file.read
        }
      else
        data = yield
        File.open(filename, File::RDWR|File::CREAT, 0644) { |file|
          file.flock(File::LOCK_EX)
          file.write JSON.pretty_generate(data)
          file.flush
          file.truncate(file.pos)
        } unless data.blank?
        data
      end
    end

    def cache_valid?(filename, expiration)
      File.exists?(filename) && !File.zero?(filename) && ((Time.now - expiration) < File.stat(filename).mtime)
    end
  end
end
