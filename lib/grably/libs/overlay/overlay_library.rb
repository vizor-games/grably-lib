require_relative 'providers'

module Grably
  module Libs
    # rubocop:disable Metrics/ClassLength
    # :nodoc:
    class OverlayLibrary < Library
      include FileUtils

      def initialize(id, version, desc, repo)
        super(id, version)

        @repo = repo

        m = /(.+):(.+)/.match(id)
        raise "wrong library id: #{id}" if m.nil?
        @group = m[1]
        @name = m[2]

        @slot = 'bin'
        @install = []
        @work_dir = ''

        @desc = File.join(File.expand_path(desc), "#{full_name}.rb")

        begin
          instance_eval(IO.read(@desc))
        rescue StandardError => e
          log_msg "error in build script for library: #{id}-#{version}"
          raise e
        end

        setup
      end

      def setup
        # do nothing by default
      end

      attr_reader :name, :group, :slot

      def full_name
        "#{@name}-#{@version}"
      end

      def full_id
        "#{@id}-#{@version}"
      end

      def tmp_path(*path)
        @repo.repo_path('overlay', 'tmp', *path)
      end

      def work_path(*path)
        tmp_path('build', @work_dir, *path)
      end

      def lib_path(*path)
        @repo.repo_path('overlay', 'files', slot, *path)
      end

      def result_file
        lib_path('.result')
      end

      def digest_file
        lib_path('.digest')
      end

      def desc_path(*path)
        File.expand_path(File.join(File.dirname(@desc), *path))
      end

      def deps
        r = @rdeps || []
        r = [r] unless r.is_a?(Array)
        r.uniq
      end

      def build_deps
        r = @bdeps || @rdeps || []
        r = [r] unless r.is_a?(Array)
        r.uniq
      end

      def get
        if dirty?
          @bdeps_resolved = @repo.get(@bdeps, @name)
          @bdeps_by_name = {}
          @bdeps_resolved.each do |s|
            k = s[:lib_name]
            unless k.nil?
              @bdeps_by_name[k] = [] unless @bdeps_by_name.key?(k)
              @bdeps_by_name[k] << s
            end
          end

          log_msg 'Building library '.yellow + @name.yellow.bright

          # Recreate tmp folder
          t = tmp_path
          rm_rf(t)
          mkdir_p(t)

          # Build steps
          log_msg '* Fetching'
          fetch

          log_msg '* Unpacking'
          unpack

          if respond_to? :patch
            log_msg '* Patching'
            patch
          end

          if respond_to? :compile
            log_msg '* Compiling'
            compile
          end

          # Install
          rm_rf(lib_path)
          mkdir_p(lib_path)
          files = Grably.cp(@install, lib_path)
          files.map! { |f| f.update(lib_name: @name, lib_version: @version) }
          save_obj(result_file, files)
          save_obj(digest_file, digest(@desc))

          rm_rf(t)
        end

        load_obj(result_file)
      end

      def dirty?
        digest(@desc) != load_obj(digest_file)
      end

      def install(src)
        @install << src
      end

      def fetch
        Provider.providers.each do |provider|
          params = instance_variable_get("@#{provider.config_var}")
          next if params.nil?

          params = [params] unless params.is_a?(Array)
          params.each do |param|
            param = param.clone

            dir = param.delete(:dir) if param.is_a?(Hash)
            dir ||= ''

            p = provider.new(param)
            dist_file = @repo.repo_path('overlay', 'dist', p.filename)
            unless File.exist?(dist_file)
              tmp_dist_dir = tmp_path('download')
              tmp_dist_file = File.join(tmp_dist_dir, p.filename)
              mkdir_p(tmp_dist_dir)
              p.fetch(tmp_dist_dir)

              raise 'internal error' unless File.exist?(tmp_dist_file)
              mkdir_p(File.dirname(dist_file))
              mv(tmp_dist_file, dist_file)
              rm_rf(tmp_dist_dir)
            end

            dest_dir = tmp_path('build', dir)
            mkdir_p(dest_dir)
            ln(dist_file, File.join(dest_dir, p.filename))
          end
        end
      end

      def unpack_all(mask)
        Dir.glob(tmp_path('build', mask)) do |f|
          Grably.unpack(f, File.dirname(f))
          rm(f)
        end
      end

      def unpack
        unpack_all('*.{zip,gz,tgz}')
      end
    end
  end
end
