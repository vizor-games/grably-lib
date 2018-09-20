module Grably # :nodoc:
  module Libs
    class MavenLibrary < Library # :nodoc:
      def initialize(id, version, real_version, libs)
        super(id, version)
        @libs = libs
        @real_version = real_version
        @group, @name = @libs.parse_id(id)

        pom_path = @libs.download(nil, @libs.id_path(id), @real_version, "#{@name}-#{@real_version}.pom")
        doc = REXML::Document.new(IO.read(pom_path))

        @deps = []
        doc.each_element('/project/dependencies/dependency') do |e|
          dep_group = e.elements['groupId'].text
          dep_name = e.elements['artifactId'].text
          scope_e = e.elements['scope']
          scope = scope_e.nil? ? '' : scope_e.text

          next unless ['', 'runtime'].include?(scope)

          @deps << "#{dep_group}:#{dep_name}"
        end
      end

      attr_reader :deps

      def get
        jar = @libs.download(nil, @libs.id_path(id), @real_version, "#{@name}-#{@real_version}.jar")
        Product.new(jar, nil, lib_id: id, lib_group: @group, lib_name: @name, lib_version: @version)
      end
    end

    class MavenLibraries < Libraries # :nodoc:
      include Libs

      require 'digest'
      require 'rexml/document'

      def initialize(url = nil)
        @url = url || 'https://repo1.maven.org/maven2'
        @versions = {}
      end

      def versions(id)
        meta_path = download("Downloading versions for #{id}", id_path(id), 'maven-metadata.xml')

        doc = REXML::Document.new(IO.read(meta_path))

        @versions[id] ||= {}
        vs = []
        doc.each_element('/metadata/versioning/versions/version') do |e|
          v = Version.new(e.text)
          vs << v
          @versions[id][v] = e.text
        end

        vs
      end

      def description(id, version)
        vs = @versions[id]
        return nil if vs.nil?
        real_version = vs[version]
        return nil if real_version.nil?
        MavenLibrary.new(id, version, real_version, self)
      end

      def parse_id(id)
        m = /(.+):(.+)/.match(id)
        raise "wrong library id: #{id}" if m.nil?
        # group, name
        [m[1], m[2]]
      end

      def id_path(id)
        group, name = parse_id(id)
        [group.split('.'), name].flatten
      end

      def download(msg, *path)
        path = path.flatten

        local_path = @repo.repo_path('maven', *path)
        return local_path if File.exist?(local_path)

        log_msg msg unless msg.nil?

        url = "#{@url}/#{path.join('/')}"
        local_tmp_path = "#{local_path}.tmp"
        http_download(url, local_tmp_path, msg.nil?)
        raise 'error downloading files from maven repository' unless File.exist?(local_tmp_path)
        sha1_path = "#{local_path}.sha1"
        http_download("#{url}.sha1", sha1_path, msg.nil?)
        raise 'error downloading sha1 digest from maven repository' unless File.exist?(sha1_path)

        m = /^([0-9A-Fa-f]+).*/.match(IO.read(sha1_path))
        raise 'error parsing sha1 digest' if m.nil?

        digest = ::Digest::SHA1.hexdigest(IO.binread(local_tmp_path))
        raise 'digest mismatch' unless m[1] == digest

        FileUtils.mv(local_tmp_path, local_path)
        local_path
      end
    end
  end

  def maven_libs(url = nil)
    Libs::MavenLibraries.new(url)
  end
end
