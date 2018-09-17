require_relative 'providers'
require_relative 'library_commands'

module Grably
  module Libs
    # rubocop:disable Metrics/ClassLength
    # :nodoc:
    class OverlayLibrary < Library
      include FileUtils
      include LibCommands

      def initialize(id, version, desc, repo)
        super(id, version)

        @repo = repo

        m = /(.+):(.+)/.match(id)
        raise "wrong library id: #{id}" if m.nil?
        @group = m[1]
        @name = m[2]

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

        @lib_path = @repo.repo_path('overlay', 'files', slot, @group.split('.'), @name)
      end

      def setup
        # do nothing by default
      end

      attr_reader :name, :group

      def slot
        @slot ||= 'bin'
      end

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

      alias w work_path

      def lib_path(*path)
        File.join(@lib_path, *path)
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

      def get_deps(*list)
        return @bdeps_resolved if list.empty?

        r = []
        list.flatten.each do |l|
          r << (@bdeps_by_name[l] || raise("library #{l} is not found in deps list"))
        end

        r.flatten
      end

      def get # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        if dirty?
          @bdeps_resolved = @repo.get(build_deps, @name)
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

          log_msg '* Installing'
          install

          # Install
          rm_rf(lib_path)
          mkdir_p(lib_path)
          files = Grably.cp(expand_w(@install), lib_path)
          files.map! do |f|
            v = { lib_name: @name, lib_version: @version }
            v[:src] = Grably.cp(f[:src], lib_path) if f[:src]
            f.update(v)
          end
          save_obj(result_file, files)
          save_obj(digest_file, digest(@desc))

          rm_rf(t)
        end

        load_obj(result_file)
      end

      def dirty?
        digest(@desc) != load_obj(digest_file)
      end

      def install_lib(lib, src = nil)
        lib = expand_w(lib)
        raise 'only one build artefact is supported' unless lib.size == 1
        lib = lib[0]

        unless src.nil?
          src = expand_w(src)
          raise 'only one source file supported' unless src.size == 1
          lib = lib.update(src: src[0])
        end

        @install << lib
      end

      def install
        raise 'really nothing to install ?'
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

require_relative 'extensions/javac_lib'
