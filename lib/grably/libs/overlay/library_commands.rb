module Grably
  module Libs
    module LibCommands # :nodoc:
      require 'fileutils'
      require_relative 'patch'

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

      def preprocess_w(src, dst = nil, rm_src = nil)
        dst = src if dst.nil?
        data = yield(IO.read(w(src)))
        File.open(w(dst), 'w') do |f|
          f.print(data)
        end

        rm_src = !dst.nil? if rm_src.nil?
        rm_w(src) if rm_src
      end

      def glob_w(pattern)
        Dir.glob_base(pattern, w)
      end

      def patch_w(patch, strip_path = 1)
        Libs::Patch.patch(desc_path(patch), w, strip_path)
      end
    end
  end
end
