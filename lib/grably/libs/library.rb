require_relative 'library_version'

module Grably
  module Libs # :nodoc:
    class Library # :nodoc:
      attr_reader :id, :version

      def initialize(id, version)
        @id = id
        @version = version
      end

      # Used to get runtime dependencies
      # @return Array<String> - library runtime dependencies with restrictions
      def deps
        []
      end

      # Get library artifacts (load, build, generate, e.t.c)
      def get
        []
      end

      def to_s
        "#{@id}-#{@version}"
      end
    end
  end
end
