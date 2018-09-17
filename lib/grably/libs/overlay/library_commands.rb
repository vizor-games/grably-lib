module Grably
  module Libs
    module LibCommands # :nodoc:
      require 'fileutils'

      def mkdir_w(path)
        FileUtils.mkdir_p([path].flatten.map { |p| w(p) })
      end

      def rm_w(path)
        FileUtils.rm_rf([path].flatten.map { |p| w(p) })
      end

      def expand_w(srcs)
        Product.expand(srcs, base_dir: w)
      end

      def pack_w(srcs, dst, opts = {})
        Grably.pack(expand_w(srcs), w(dst), opts)
      end

      def unpack_w(src, dst_dir, opts = {})
        Grably.unpack(expand_w(src), w(dst_dir), opts)
      end
    end
  end
end
