module Grably
  module Libs
    module JarLib # :nodoc:
      def setup
        super

        @slot ||= 'java/bin'
      end

      def install
        jars = glob_w('*.jar')
        raise "there should be exactly one jar, found: #{jars.size}" unless jars.size == 1
        install_lib(jars[0])
      end
    end
  end
end
