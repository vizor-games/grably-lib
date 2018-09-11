module Grably
  module Libs
    class FileProvider
      attr_reader :filename

      def initialize(filename)
        @filename = filename
      end

      def self.config_var
        raise 'not implemented'
      end

      def fetch(tmp_dir)
        # do nothing by default, FileProvider is only a stub
      end
    end
  end
end
