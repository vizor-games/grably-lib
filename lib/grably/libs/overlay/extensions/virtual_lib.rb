module Grably
  module Libs
    module VirtualLib # :nodoc:
      def setup
        super

        @slot ||= 'virtual'
      end

      def install
        # do nothing
      end
    end
  end
end
