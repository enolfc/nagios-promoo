module Nagios
  module Promoo
    # Namespace for helpers and aux utilities.
    #
    # @author Boris Parak <parak@cesnet.cz>
    module Utils
      # Caching helpers for arbitrary use.
      #
      # @author Boris Parak <parak@cesnet.cz>
      module Cache
        CACHE_DIR = '/tmp/nagios-promoo_cache'.freeze

        def cache_fetch(key, expiration = 3600)
          raise 'You have to provide a block!' unless block_given?
          FileUtils.mkdir_p CACHE_DIR
          filename = File.join(CACHE_DIR, key)

          if cache_valid?(filename, expiration)
            read_cache filename
          else
            write_cache filename, yield
          end
        end

        def read_cache(filename)
          File.open(filename, 'r') do |file|
            file.flock(File::LOCK_SH)
            JSON.parse file.read
          end
        end

        def write_cache(filename, data)
          return data if data.blank?

          File.open(filename, File::RDWR | File::CREAT, 0o644) do |file|
            file.flock(File::LOCK_EX)
            file.write JSON.fast_generate(data)
            file.flush
            file.truncate(file.pos)
          end

          data
        end

        def cache_valid?(filename, expiration)
          File.exist?(filename) \
            && !File.zero?(filename) \
            && ((Time.now - expiration) < File.stat(filename).mtime)
        end
      end
    end
  end
end
