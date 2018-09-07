module Grably
  module Libs
    class VersionRange # :nodoc:
      attr_reader :lo_inc, :lo_ver, :hi_inc, :hi_ver

      def self.new_e(ver)
        VersionRange.new("[#{ver},#{ver}]")
      end

      def self.new_l(ver)
        VersionRange.new("(?,#{ver})")
      end

      def self.new_le(ver)
        VersionRange.new("(?,#{ver}]")
      end

      def self.new_g(ver)
        VersionRange.new("(#{ver},?)")
      end

      def self.new_ge(ver)
        VersionRange.new("[#{ver},?)")
      end

      def self.new_any
        VersionRange.new('(?,?)')
      end

      def initialize(range)
        if range.is_a? Array
          @lo_inc, @lo_ver, @hi_ver, @hi_inc = range
        elsif range.is_a? Version
          @lo_inc = true
          @hi_inc = true
          @lo_ver = range.clone.freeze
          @hi_ver = range.clone.freeze
        else
          @lo_inc = !range.start_with?('(')
          range = range[1..-1] if range.start_with?('[', '(')

          @hi_inc = !range.end_with?(')')
          range = range[0..-2] if range.end_with?(']', ')')

          range = range.split(',')
          @lo_ver = range[0] == '?' ? Version.min_version : Version.new(range[0])
          @hi_ver = range[1] == '?' ? Version.max_version : Version.new(range[1])
        end
      end

      def to_s
        (@lo_inc ? '[' : '(') + @lo_ver.to_s + ',' + @hi_ver.to_s + (@hi_inc ? ']' : ')')
      end

      def inspect
        to_s
      end

      def =~(other)
        return true if other > @lo_ver && other < @hi_ver
        return true if other == @lo_ver && @lo_inc
        return true if other == @hi_ver && @hi_inc
        false
      end

      def &(other)
        if @lo_ver > other.lo_ver
          lo_ver = @lo_ver
          lo_inc = @lo_inc
        elsif @lo_ver < other.lo_ver
          lo_ver = other.lo_ver
          lo_inc = other.lo_inc
        else
          lo_ver = @lo_ver
          lo_inc = @lo_inc && other.lo_inc
        end

        if @hi_ver < other.hi_ver
          hi_ver = @hi_ver
          hi_inc = @hi_inc
        elsif @hi_ver > other.hi_ver
          hi_ver = other.hi_ver
          hi_inc = other.hi_inc
        else
          hi_ver = @hi_ver
          hi_inc = @hi_inc && other.hi_inc
        end

        return nil if hi_ver < lo_ver
        return nil if hi_ver == lo_ver && !(lo_inc && hi_inc)
        VersionRange.new([lo_inc, lo_ver, hi_ver, hi_inc])
      end
    end

    # Version consists of four section.
    # 1) a.b.c - numbers with dots, main part
    # 2) type (+number) - alpha(a), beta(b), pre, rc, <> (normal version)
    # 3) release version (+number): r
    # 4) patch version (+number): p
    #
    # Examples:
    # 1.0.10
    # 1.0.10.pre2
    # 1.0.10.a1
    class Version
      include Comparable

      SUBVERSIONS_BACK = { -4 => 'alpha', -3 => 'beta', -2 => 'pre', -1 => 'rc' }.freeze
      SUBVERSIONS = SUBVERSIONS_BACK.invert.freeze

      attr_reader :ver, :type, :type_ver, :rev, :patch

      def initialize(ver)
        parts = ver.split(/\./)

        @patch = 0
        @patch = Integer(parts.pop[1..-1]) if prefix(parts.last) == 'p'

        @rev = 0
        @rev = Integer(parts.pop[1..-1]) if prefix(parts.last) == 'r'

        @type = 0
        @type_ver = 0

        p = prefix(parts.last)
        if SUBVERSIONS.key?(p)
          @type = SUBVERSIONS[p]
          @type_ver = Integer(parts.pop[p.size..-1])
        end

        @ver = parts

        # rescue
        #  raise "wrong version: #{ver}"
      end

      def =~(other)
        return other =~ self if other.is_a?(VersionRange)
        other == self
      end

      def <=>(other)
        other = Version.new(other) unless other.is_a?(Version)

        r = compare_base(other)

        return r unless r.zero?
        return @type <=> other.type unless (@type <=> other.type).zero?
        return @type_ver <=> other.type_ver unless (@type_ver <=> other.type_ver).zero?
        return @rev <=> other.rev unless (@rev <=> other.rev).zero?
        @patch <=> other.patch
      end

      def to_s
        r = @ver * '.'
        r += '.' + SUBVERSIONS_BACK[@type].to_s + @type_ver.to_s if SUBVERSIONS_BACK.key?(@type)
        r += '.r' + @rev.to_s if @rev != 0
        r += '.p' + @patch.to_s if @patch != 0
        r
      end

      def inspect
        to_s
      end

      def self.min_version
        MIN_VERSION
      end

      def self.max_version
        MAX_VERSION
      end

      def compare_base(o)
        i = 0
        ver1 = @ver
        ver2 = o.ver

        while i < ver1.length && i < ver2.length
          begin
            r = Integer(ver1[i]) <=> Integer(ver2[i])
          rescue StandardError
            r = ver1[i] <=> ver2[i]
          end

          return r unless r.zero?
          i += 1
        end

        return -1 if i >= ver1.length
        return 1 if i >= ver2.length
        0
      end

      def prefix(part)
        /([^0-9]*).*/.match(part)[1]
      end

      MIN_VERSION = Version.new('0')
      MAX_VERSION = Version.new('999999999999999999999999')
    end

    class LibRangeParams # :nodoc:
      attr_reader :group, :name, :version

      def initialize(l)
        version = VersionRange.new_any

        m = /(.+):(.+)-([^-]+)/.match(l)
        v = m[3]
        if l.start_with?('~')
          version = VersionRange.new(v)
          l = m[1][1..-1]
        elsif l.start_with?('=')
          version = VersionRange.new_e(v)
          l = m[1][1..-1]
        elsif l.start_with?('>=')
          version = VersionRange.new_ge(v)
          l = m[1][2..-1]
        elsif l.start_with?('>')
          version = VersionRange.new_g(v)
          l = m[1][1..-1]
        elsif l.start_with?('<=')
          version = VersionRange.new_le(v)
          l = m[1][2..-1]
        elsif l.start_with?('<')
          version = VersionRange.new_l(v)
          l = m[1][1..-1]
        end

        @name = l
        @version = version
      end

      def to_s
        "#{id}-#{@version}"
      end

      def id
        "#{group}:#{@name}"
      end

      def inspect
        to_s
      end
    end

    class LibParams # :nodoc:
      attr_reader :group, :name, :version

      def initialize(l)
        m = /(.+):(.+)-([^-]+)/.match(l)
        @group = m[1]
        @name = m[2]
        @version = Version.new(m[3])
      end

      def to_s
        "#{id}-#{@version}"
      end

      def id
        "#{@group}:#{@name}"
      end

      def inspect
        to_s
      end
    end
  end
end
