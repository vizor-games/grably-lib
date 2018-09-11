require 'open-uri'
require 'openssl'

module OpenURI
  class << self
    alias_method :redirectable_cautious?, :redirectable?

    def redirectable?(uri1, uri2)
      redirectable_cautious?(uri1, uri2) || http_to_https?(uri1, uri2) || https_to_http?(uri1, uri2)
    end

    def http_to_https?(uri1, uri2)
      schemes_from([uri1, uri2]) == %w(http https)
    end

    def https_to_http?(uri1, uri2)
      schemes_from([uri1, uri2]) == %w(https http)
    end

    def schemes_from(uris)
      uris.map { |u| u.scheme.downcase }
    end
  end
end

module Grably
  module Libs
    module_function

    # progress can be: false, true or :delayed
    def http_download(url, path, progress, params = {})
      FileUtils.mkdir_p(File.dirname(path))

      shown = false

      begin
        name = File.basename(path)

        total = nil

        cl_proc = lambda do |t|
          total = t if t && t > 0
        end

        p_proc = lambda do |s|
          if progress
            if total
              print "Downloading #{name}: #{((s * 100) / total).to_i}%...\r"
            else
              print "Downloading #{name}: ?%...\r"
            end
            shown = true
          end
        end

        if progress && progress != :delayed
          print "Downloading #{name}: 0%...\r"
          shown = true
        end

        params = { :read_timeout => 10, content_length_proc: cl_proc, progress_proc: p_proc, :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE }.merge(params)

        stream = open(url, params)

        File.open(path, "w") do |f|
          IO.copy_stream(stream, f)
        end

        puts "Downloading #{name}: 100%..." if progress
      rescue StandardError => e
        puts "\nDownload FAILED" if shown
        FileUtils.rm(path)
        raise e
      end
    end
  end
end
