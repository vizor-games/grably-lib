require_relative 'file_provider'

module Grably
  module Libs
    class HttpProvider < FileProvider # :nodoc:
      include Provider
      include Libs

      require 'uri'

      def initialize(p = {})
        p = { url: p } unless p.is_a?(Hash)

        @url = p.delete(:url)
        @params = p.delete(:params) || {}

        filename = p.delete(:filename) || File.basename(URI(@url).path)

        super(filename)
      end

      def fetch(tmp_dir)
        http_download(@url, File.join(tmp_dir, filename), true, @params)
      end

      def self.config_var
        'src'
      end
    end
  end
end
