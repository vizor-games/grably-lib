require_relative 'overlay_library'
require_relative 'overlays/git_overlay'

module Grably # :nodoc:
  module Libs # :nodoc:
    # Local specific to grably type of libraries.
    # Libraries are compiled/downloaded using special .rb descriptions.
    class OverlayLibraries < Libraries
      def initialize(overlay_path)
        @overlay_path = File.expand_path(overlay_path)
      end

      def versions(id)
        group, name = parse_id(id)

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

      def parse_id(id)
        m = /(.+):(.+)/.match(id)
        raise "wrong library id: #{id}" if m.nil?
        # group, name
        [m[1], m[2]]
      end

      def desc_dir(id)
        group, name = parse_id(id)
        File.join(@overlay_path, group.split(/\./), name)
      end
    end
  end

  def overlay_libs(*paths)
    paths.map { |path| Libs::OverlayLibraries.new(path) }
  end

  def load_overlay_libs(uri, type, local_path = nil, lock_file = nil)
    raise 'only git overlay type is supported' unless type == :git

    local_path ||= '.grably/overlay'
    lock_file ||= 'libs.lock'

    rev = nil
    rev = IO.read(lock_file).strip if File.exist?(lock_file)
    rev = nil if rev == ''

    loader = Libs::GitOverlay.new(uri, local_path)
    crev = loader.current_rev
    if crev.nil? || crev != rev
      log_msg "Updating remote overlay libraries from: #{uri}".yellow
      loader.fetch(rev)
      File.open(lock_file, 'w') do |f|
        f.print loader.current_rev
      end
    end

    overlay_libs(local_path)
  end
end
