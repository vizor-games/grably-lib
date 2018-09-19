require_relative 'http_provider'

module Grably
  module Libs
    class BundleProvider < HttpProvider # :nodoc:
      def initialize(service, p = {})
        project = p.delete(:project)
        revision = p.delete(:rev).to_s
        filename = "#{service}-#{project.split('/').join('-')}-#{revision.split('/').join('-')}.tar.gz"
        super(url: yield(project, revision), filename: filename)
      end

      def fetch(tmp_dir)
        super(tmp_dir)

        fn = File.join(tmp_dir, filename)
        unp_dir = File.join(tmp_dir, 'unp')

        unpack(fn, unp_dir)
        FileUtils.rm(fn)

        dirs = Dir.glob(File.join(unp_dir, '*'))
        raise 'there should be only one dir in archive' unless dirs.size == 1

        pack(dirs[0], fn)
      end
    end
  end
end
