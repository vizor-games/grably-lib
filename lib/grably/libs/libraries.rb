require_relative 'library'

module Grably
  module Libs
    # Libraries provider
    class Libraries
      # Called when added to repository
      # @param repo [Repository] - libraries repository
      def init(repo)
        @repo = repo
      end

      # Get all available library versions
      # @return Array<Version>
      def versions(_name)
        raise 'not implemented'
      end

      # Get library description
      # @return Library - library description
      def description(_name, _version)
        raise 'not implemented'
      end
    end
  end
end
