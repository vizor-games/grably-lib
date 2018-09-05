module GrablyPkg
  require 'set'

  class Library
    def extend(o)
      super(o)
      init
    end

    def init
      # Do nothing here
    end

    def initialize(group, name, file)
      @group = group
      @name = name
      @file = file
      @full_name = File.basename(file, '.rb')
      m = /(.+)-([^-]+)/.match(@full_name)
      raise "wrong package name for #{@full_name}"
      @name = m[1]
      @version = m[2]
      @signature = @full_name

      @installed = []

      @patch_dir = File.dirname(@file)

      begin
        instance_eval(IO.read(file))
      rescue StandardError => e
        log "error in build script for library #{@signature}"
        raise e
      end

      setup
    end

    def to_s
      @signature
    end

    def inspect
      to_s
    end

    def setup
      # Do nothing by default
    end

    def build_all
      if dirty?
        @build_deps = get(build_deps, @name)
        @build_deps_by_lib = {}
        @build_deps.each do |d|
          k = d[:lib_name]
          unless k.nil?
            @build_deps_by_lib[k] = [] unless @build_deps_by_lib.has_key?(k)
            @build_deps_by_lib[k] << d
          end
        end

        log "#{color(:yellow)}BUILDING library #{color(:bright)}#{@signature}#{color_reset}"

        #rm(lib_path) # Удаление и создание lib_path теперь будет в самой либе. Это надо, чтобы не плодить ошибок для других, если либа не собралась
        rm(tmp_path)

        #mkdir(lib_path)
        mkdir(tmp_path)

        pwd = Dir.pwd
        Dir.chdir(tmp_path)
        # Запускаем сборку
        build
        Dir.chdir(pwd)

        # Cleanup tmp dir
        log "* Cleaning"
        rm(tmp_path)

        @installed.flatten!
        @installed.uniq!
        save_obj(result_file, @installed)
        save_obj(digest_file, file_digest(@file, true))
      end

      load_obj(result_file)
    end

    def build
      raise "unimplemented build function !"
    end

    def tmp_path
      repo_dir('tmp', 'build', ENV['mlibtmp'])
    end

    def lib_path(*args)
      repo_dir('lib', @SLOT, @signature, *args)
    end

    def patch(patch_file)
      unless File.exist?(patch_file)
        p = patch_path(patch_file)
        patch_file = p if File.exist?(p)
      end
      super(patch_file)
    end

    def patch_path(*args)
      File.join(@patch_dir, args)
    end

    def use_flags
      uf = @USE_FLAGS || []
      uf = [ uf ] unless uf.is_a? Array
      (uf.map { |f| f.to_s }).to_set
    end

    def use?(flag)
      @req_use_flags.include?(flag.to_s)
    end

    def result_file
      lib_path('.result')
    end

    def digest_file
      lib_path('.digest')
    end

    def dirty?
      file_digest(@file) != load_obj(digest_file)
    end

    def build_deps
      r = @BDEPS || @RDEPS || []
      r = [ r ] unless r.is_a? Array
      r.uniq
    end

    def runtime_deps
      r = @RDEPS || []
      r = [ r ] unless r.is_a? Array
      r.uniq
    end

    def get_deps(*list)
      return @build_deps if list.size == 0
      list.flatten!
      r = []
      list.each do |l|
        d = @build_deps_by_lib[l]
        raise "library #{l} is not found in deps list" if d.nil?
        r << d
      end
      return r.flatten
    end

    def get_deps_classpath(*list)
      create_classpath(get_deps(*list))
    end

    def get_dep_lib(name, postfix = '')
      postfix = "-#{postfix}" if postfix.size > 0
      libs = get_deps(name)
      libs.each do |l|
        fn = /(.*)\.[^\.]*/.match(File.basename(l.dst))[1]
        return l if fn == "#{l[:lib_full_name]}#{postfix}"
      end
      raise "lib file with postfix '#{postfix}' was not found for dep library '#{name}'"
    end

    def link_lib(link_to, name, postfix = '')
      lib = get_dep_lib(name, postfix)
      mkdir(File.dirname(link_to))
      rm(link_to)
      ln_sys(lib.src, link_to)
    end

    def replace_lib_name(name)
      name.gsub('*', @full_name)
    end

    # Тут мы не только создаём библиотеку, но и копируем её в lib_path
    def create_lib(file, name, src_file = nil, src_name = nil)
      raise "create lib needs name with file defined" if file.nil? || name.nil?

      name = replace_lib_name(name)
      lib_file = lib_path(name)
      mkdir(File.dirname(lib_file))
      cp_sys(file, lib_file)

      p = Product.new(lib_file, name)

      unless src_file.nil?
        src_name = "*-src.zip" if src_name.nil?
        src_name = replace_lib_name(src_name)

        src_file = zip(src_file, src_name) unless src_file.is_a?(String) && File.file?(src_file)

        lib_src_file = lib_path(src_name)
        mkdir(File.dirname(lib_src_file))
        cp_sys(src_file, lib_src_file)

        p[:src] = lib_src_file
      end

      # Добавляем всякие полезные метаданные в библиотеку
      p[:lib_full_name] = @full_name
      p[:lib_name] = @name
      p[:lib_version] = @version
      p[:lib_flags] = @req_use_flags

      return p
    end

    def install(*lib)
      if (lib.size == 1) || (lib.size == 2 && lib[1].nil?)
        install_bin(lib[0])
      elsif lib.size >= 1 && lib.size <= 4 && lib[0].is_a?(String)
        @installed << create_lib(*lib)
      else
        raise "wrong install lib: #{lib.inspect}"
      end
    end

    def install_bin(srcs, dir = '')
      srcs = MBuild::Product.expand(srcs)
      dir = lib_path(dir)
      mkdir(dir)
      cp(srcs, dir)
    end

  end
end
