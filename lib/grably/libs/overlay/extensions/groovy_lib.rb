module Grably
  module Libs
    module GroovyLib # :nodoc:
      require 'grably/java'
      include Java

      def setup
        super

        @build_dir ||= '.build'
        @build_jar ||= "#{full_name}.jar"
        @build_srcs ||= "#{full_name}-src.zip"
        @res ||= []
        @libs ||= []
        @joint = true if @joint.nil?

        @slot = "java/#{@slot || JAVA_TARGET}"
      end

      def compile
        srcs_filtered = { @srcs || 'src' => '**/*.{java,groovy}' }
        srcs = expand_w(srcs_filtered)
        mkdir_w(@build_dir)

        cp = get_deps
        cp << expand_w(@libs)
        cp << w(@build_dir)
        cp = classpath(cp)
        cp = cp.empty? ? nil : ['-classpath', cp]

        d = srcs.map { |s| s.to_s.tr('\\', '/') }.join("\n")
        srcs_tmp = w('srcs-tmp-file')
        File.open(srcs_tmp, 'w') { |f| f.print(d) }

        compiler_cp = classpath(get_deps('org.codehaus.groovy:groovy'))

        cmd = [java_cmd, '-cp', compiler_cp, 'org.codehaus.groovy.tools.FileSystemCompiler', cp]
        cmd += ['-j'] if @joint
        cmd += ['-d', w(@build_dir), "@#{srcs_tmp}"]
        cmd.run

        post_compile

        pack_w([@build_dir, @res], @build_jar)
        pack_w(srcs_filtered, @build_srcs)
      end

      def post_compile
        # do nothing by default
      end

      def install
        install_lib(@build_jar, @build_srcs)
      end
    end
  end
end
