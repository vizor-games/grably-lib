require_relative 'overlay_library'

module Grably
  module Libs # :nodoc:
    # Local specific to grably type of libraries.
    # Libraries are compiled/downloaded using special .rb descriptions.
    class OverlayLibraries < Libraries
      def initialize(overlay_path)
        @overlay_path = File.expand_path(overlay_path)
      end

      def versions(id)
        m = /(.+):(.+)/.match(id)
        raise "wrong library id: #{id}" if m.nil?
        group = m[1]
        name = m[2]

        dir = desc_dir(id)
        return [] unless File.exist?(dir)
        vs = Dir.glob(File.join(dir, "#{name}-*.rb")).map do |f|
          LibParams.new("#{group}:#{File.basename(f, '.rb')}")
        end

        vs.each { |v| raise "wrong directory structure for: #{id}" unless v.id == id }

        vs.map(&:version)
      end

      def description(id, version)
        OverlayLibrary.new(id, version, desc_dir(id), @repo)
      end

      private

      def desc_dir(id)
        File.join(@overlay_path, id.split(/[.:]/))
      end
    end
  end
end
