module Grably # :nodoc:
  module Libs
    class GitOverlay # :nodoc:
      def initialize(uri, local_path)
        @uri = uri
        @local_path = local_path
      end

      def current_rev
        return nil unless File.exist?(File.join(@local_path, '.git'))
        %w(git rev-parse HEAD).run(chdir: @local_path)
      rescue StandardError
        nil
      end

      def fetch(rev)
        unless File.exist?(File.join(@local_path, '.git'))
          FileUtils.mkdir_p(@local_path)
          %w(git init).run(chdir: @local_path)
          ['git', 'remote', 'add', 'origin', @uri].run(chdir: @local_path)
        end

        %w(git fetch).run_log(chdir: @local_path)
        ['git', 'reset', '--hard', rev.nil? ? 'origin/master' : rev].run(chdir: @local_path)
      end
    end
  end
end
