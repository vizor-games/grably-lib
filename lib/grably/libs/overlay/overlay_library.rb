require_relative 'providers'

module Grably
  module Libs
    class OverlayLibrary < Library # :nodoc:
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

          log_msg "Building library ".yellow + @name.yellow.bright

          # Recreate tmp folder
          t = tmp_path
          FileUtils.rm_rf(t)
          FileUtils.mkdir_p(t)

          # Build steps
          log_msg "* Fetching"
          fetch

          log_msg "* Unpacking"
          unpack

          if self.respond_to? :patch
            log_msg "* Patching"
            patch
          end

          if self.respond_to? :compile
            log_msg "* Compiling"
            compile
          end

          # Install
          FileUtils.rm_rf(lib_path)
          FileUtils.mkdir_p(lib_path)
          files = Grably::cp(@install, lib_path)
          files.map! { |f| f.update(lib_name: @name, lib_version: @version) }
          save_obj(result_file, files)
          save_obj(digest_file, digest(@desc))

          FileUtils.rm_rf(t)
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
          params = instance_variable_get(provider.config_var)
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
              FileUtils.mkdir_p(tmp_dist_dir)
              p.fetch(tmp_dist_dir)

              raise 'internal error' unless File.exist?(tmp_dist_file)
              FileUtils.mkdir_p(File.dirname(dist_file))
              FileUtils.mv(tmp_dist_file, dist_file)
              FileUtils.rm_rf(tmp_dist_dir)
            end

            FileUtils.ln(dist_file, tmp_path('build', dir))
          end
        end
      end

      def unpack_all(mask)
        Dir.glob(tmp_path('build', mask)) do |f|
          Grably::unpack(f, File.dirname(f))
          FileUtils.rm(f)
        end
      end

      def unpack
        unpack_all("*.{zip,gz,tgz}")
      end
    end
  end
end
