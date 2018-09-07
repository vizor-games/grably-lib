module Grably
  module Libs # :nodoc:
    # Local specific to grably type of libraries.
    # Libraries are compiled/downloaded using special .rb descriptions.
    class OverlayLibraries < Libraries
      def initialize(overlay_path)
        @overlay_path = File.expand_path(overlay_path)
      end

      def versions(name)
        m = /(.+):(.+)/.match(name)
        raise "wrong library name: #{name}" if m.nil?
        dir = desc_dir(name)
        return [] unless File.exist?(dir)
        id = m[2]
        vs = Dir.glob(File.join(dir, "#{id}-*.rb")).map do |f|
          LibParams.new(File.basename(f, '.rb'))
        end

        vs.each { |v| raise "wrong directory structure for: #{name}" unless v.name == id }

        vs.map(&:version)
      end

      def description(name, version)
        # TODO: add code
        Library.new(name, version)
      end

      private

      def desc_dir(name)
        File.join(@overlay_path, name.split(/[.:]/))
      end
    end
  end
end
