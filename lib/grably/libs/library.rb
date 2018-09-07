require_relative 'library_version'

module Grably
  module Libs # :nodoc:
    class Library # :nodoc:
      def initialize(name, version)
        @name = name
        @version = version
      end

      # Used to get runtime dependencies
      # @return Array<String> - library runtime dependencies with restrictions
      def deps
        []
      end

      # Get library artifacts (load, build, generate, e.t.c)
      def build
        []
      end

      # Check if this library needs to be rebuilt
      def dirty?
        false
      end
    end
  end
end
