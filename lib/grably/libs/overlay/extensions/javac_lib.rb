module Grably
  module Libs
    module JavacLib # :nodoc:
      require 'grably/java'
      include Java

      def setup
        super

        @build_dir ||= '.build'
        @build_jar ||= "#{full_name}.jar"
        @build_srcs ||= "#{full_name}-src.zip"
        @res ||= []
        @jdk_tools = false if @jdk_tools.nil?
        @libs ||= []
        @debug = false if @debug.nil?

        if @java_boot
          @bdeps ||= @rdeps
          @bdeps = [@bdeps, "java-rt-#{@java_boot}"].flatten.compact
        end

        @slot = "java/#{@slot || JAVA_TARGET}"
      end

      def compile
        srcs_filtered = { @srcs || 'src' => '**/*.java' }
        srcs = expand_w(srcs_filtered)
        mkdir_w(@build_dir)

        cp = get_deps
        cp << "#{JDK_HOME}/lib/tools.jar" if @jdk_tools
        cp << expand_w(@libs)
        cp = classpath(cp)
        cp = cp.empty? ? nil : ['-classpath', cp]

        debug = @debug ? '-g' : nil

        d = srcs.map { |s| s.to_s.tr('\\', '/') }.join("\n")
        srcs_tmp = w('srcs-tmp-file')
        File.open(srcs_tmp, 'w') { |f| f.print(d) }

        cmd = [javac_cmd(source: @java_source, target: @java_target), cp, debug]
        cmd += ['-bootclasspath', classpath(get_deps("java-rt-#{@java_boot}"))] if @java_boot
        cmd += ['-encoding', @java_encoding] if @java_encoding
        cmd += @java_opts if @java_opts
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
