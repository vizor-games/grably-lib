require 'grably'
require_relative 'libs/version'
require_relative 'libs/libraries'

require_relative 'libs/overlay/overlay_libraries'

module Grably
  module Libs # :nodoc:
    # Libraries repository.
    # This class manages libraries providers
    # rubocop:disable Metrics/ClassLength
    class Repository
      # Initialize repository
      # @param repo_path [String] - path to local repository storage
      def initialize(repo_path = nil)
        @repo_path = repo_path || File.expand_path('~/.grably')
        @libs = []
        @lock = nil

        # loaded library versions
        @lib_versions = {}
        # loaded library descriptions
        @lib_desc = {}
      end

      def add_libs(libs)
        @libs << libs
        libs.init(self)
      end

      alias add add_libs
      alias << add_libs

      def repo_path(*path)
        File.join(@repo_path, *path)
      end

      # Get libraries from repository.
      # @param libs [Array<String>] - libraries descriptions with restrictions
      def get(libs, exclude = nil)
        libs = get_with_deps(libs, exclude)

        # Print info messages if supported
        libs.each do |l|
          l[:lib].info_do if l[:lib].respond_to?(:info_do)
        end

        r = []
        libs.each do |l|
          o = l[:lib]

          # Lock for build
          if @lock.nil?
            lock_file = repo_path('.lock')
            FileUtils.mkdir_p(repo_path)
            # TODO: probably we need to handle somehow touch errors (in case of locked file)
            FileUtils.touch(lock_file) unless File.exist?(lock_file)
            @lock = File.new(lock_file)
            @lock.flock(File::LOCK_EX)
            begin
              rr = build_lib(o)
            ensure
              @lock.flock(File::LOCK_UN)
              @lock = nil
            end
          else
            rr = build_lib(o)
          end

          rr.map! { |e| e.update(l[:meta]) } unless l[:meta].empty?
          r << rr
        end

        r.flatten
      end

      private

      def build_lib(lib_desc)
        lib_desc.get
      end

      def find_desc(lib_params)
        libs = versions(lib_params)[lib_params.version]
        libs.nil? ? nil : libs.description(lib_params.id, lib_params.version)
      end

      def description(lib_params)
        k = lib_params.to_s
        @lib_desc[k] = find_desc(lib_params) unless @lib_desc.key?(k)
        @lib_desc[k]
      end

      def find_versions(lib_params)
        vs = {}
        @libs.each do |libs|
          libs.versions(lib_params.id).each do |v|
            vs[v] = libs unless vs.key?(v)
          end
        end

        vs
      end

      def versions(lib_params)
        k = lib_params.id
        @lib_versions[k] = find_versions(lib_params) unless @lib_versions.key?(k)
        @lib_versions[k]
      end

      def versions?(lib_params)
        !versions(lib_params).empty?
      end

      def get_with_deps(libs, exclude = nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        exclude = [] if exclude.nil?
        unless exclude.is_a?(Set)
          exclude = [exclude] unless exclude.is_a?(Array)
          exclude = exclude.to_set
        end

        i = 0
        root_map = {}
        add_libs = lambda do |ls, meta, pushed|
          ls = [ls] unless ls.is_a?(Array)
          ls = ls.flatten.compact
          id = "*#{i}-0"
          i += 1
          ls.reject! do |l|
            if l.is_a?(Hash)
              l.each do |k, v|
                add_libs.call(k, v, id)
              end
              true
            else
              false
            end
          end
          ls.flatten!
          root_map[id] = { libs: ls, meta: meta, pushed: pushed }
        end

        add_libs.call(libs, {}, '')

        added = []
        libs = {}
        root_map.each do |k, v|
          root = LibParams.new(k)
          libs[root.to_s] = create_lib_entry(v[:libs], root.to_s)
          added << { lib: root, pushed: [v[:pushed]] }
        end

        repo = {}

        r = calc_deps(added, libs, repo)

        by_push = {}
        r.each do |a|
          a[:pushed].each do |p|
            by_push[p] = [] unless by_push.key?(p)
            by_push[p] << a
          end
        end

        root_map.each do |k, v|
          next if v[:meta].empty?

          done_proc = Set.new
          for_proc = [k]
          until for_proc.empty?
            a = for_proc.shift
            next unless by_push.key?(a)

            by_push[a].each do |ba|
              ba[:meta] = {} if ba[:meta].nil?
              ba[:meta].merge!(v[:meta])
              for_proc << ba[:lib].to_s if done_proc.add?(ba[:lib].to_s)
            end
          end
        end

        r.reject! { |a| a[:lib].id.start_with?('*') || exclude.include?(a[:lib].id) }
        r = r.map { |a| { lib: repo[a[:lib].to_s], meta: a[:meta] || {} } }
        r.compact
      end

      def find_prev(added, id)
        idx = added.index { |a| a[:lib].id == id }
        idx.nil? ? nil : added[idx]
      end

      def delete_prev(added, lp)
        added.reject! { |a| a[:lib].id == lp.id }

        lps = lp.to_s

        for_delete = []
        added.each do |a|
          a[:pushed].delete(lps)
          for_delete << a[:lib] if a[:pushed].empty?
        end

        for_delete.each { |lpd| delete_prev(added, lpd) }
      end

      def calc_deps(added, libs, repo)
        changed = true

        while changed
          changed = false

          r = {}
          added.each { |a| libs[a[:lib].to_s][:normal].each { |f| f.call(r) } }
          added.each { |a| libs[a[:lib].to_s][:unsure].each { |f| f.call(r) } }

          for_delete = []

          r.each do |name, p|
            next if p[:pushed].empty?

            l = p[:libs].max_by { |lib| lib[:v] }

            raise "library is restricted: #{name}" if l.nil?

            entry = "#{name}-#{l[:v]}"
            lp = LibParams.new(entry)

            unless repo.key?(entry)
              l = description(lp)
              repo[entry] = l
              libs[entry] = create_lib_entry(l.deps, entry)
            end

            prev = find_prev(added, lp.id)
            if prev.nil?
              added << { lib: lp, pushed: p[:pushed].clone }
              changed = true
            elsif prev[:lib].version != lp.version
              for_delete << prev[:lib]
              changed = true
            else
              prev[:pushed] = p[:pushed].clone
            end
          end

          for_delete.each { |a| delete_prev(added, a) }
        end

        added
      end

      def create_lib_entry(libs, pushed)
        libs = [libs] unless libs.is_a?(Array)
        normal = []
        unsure = []
        libs.each do |lib|
          (unsure_constraint?(lib) ? unsure : normal) << create_constraint_filter(lib, pushed)
        end
        { normal: normal, unsure: unsure }
      end

      def unsure_constraint?(lib)
        lib.include?('||')
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      def create_constraint_filter(lib, pushed)
        if lib.include?('||')
          fs = []
          lib.split('||').each do |l|
            l.strip!
            raise "'!' is not supported with '||' operator: #{lib}" if l.start_with?('!')

            lp = LibRangeParams.new(l)
            idx = fs.index { |a| a[0].id == lp.id }
            if idx
              fs[idx] << lp
            else
              fs << [lp]
            end
          end

          # rubocop:disable Metrics/BlockLength
          lambda do |libset|
            selected = nil
            fs.each do |lpa|
              if libset.key?(lpa[0].id)
                fits = false
                lpa.each do |lp1|
                  next unless libset[lp1.id][:libs].index { |l| l[:v] =~ lp1.version }
                  selected = lpa
                  fits = true
                  break
                end
                break if fits
              elsif selected.nil?
                selected = lpa
              end
            end

            raise "no lib was selected by: #{lib}" if selected.nil?

            lp = selected[0]

            unless libset.key?(lp.id)
              raise "library '#{lp.id}' not found" unless versions?(lp)
              libset[lp.id] = { libs: versions(lp).keys.map { |v| { v: v } }, pushed: Set.new }
            end

            libset[lp.id][:libs].select! do |l|
              fits = false
              selected.each do |lpv|
                # TODO: check if |= is proper code
                fits |= l[:v] =~ lpv.version
              end

              fits
            end

            libset[lp.id][:pushed] << pushed
          end
        else
          negate = false
          if lib.start_with?('!')
            negate = true
            lib = lib[1..-1]
          end

          lp = LibRangeParams.new(lib)

          lambda do |libset|
            unless libset.key?(lp.id)
              raise "library '#{lp.id}' not found" unless versions?(lp)
              libset[lp.id] = { libs: versions(lp).keys.map { |v| { v: v } }, pushed: Set.new }
            end

            if negate
              libset[lp.id][:libs].reject! { |l| l[:v] =~ lp.version }
            else
              libset[lp.id][:libs].select! { |l| l[:v] =~ lp.version }
              libset[lp.id][:pushed] << pushed
            end
          end
        end
      end
    end
  end
end
