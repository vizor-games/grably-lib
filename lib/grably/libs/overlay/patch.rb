module Grably
  module Libs
    module Patch # :nodoc:
      class << self
        FILE_PATTERN = /([^\t\n]+)(?:\t'{2}?([^']+)'{2}?)?/
        OLD_FILE_PATTERN = /^--- #{FILE_PATTERN}/
        NEW_FILE_PATTERN = /^\+\+\+ #{FILE_PATTERN}/

        CHUNK_PATTERN = /^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@/
        ADDED_PATTERN = /^\+(.*)/m
        REMOVED_PATTERN = /^-(.*)/m
        UNCHANGED_PATTERN = /^ (.*)/m

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
        def patch(patch_file, path, strip_path)
          files = {}
          file = nil
          chunk = nil

          # rubocop:disable Metrics/BlockLength
          IO.readlines(patch_file).each do |line|
            if (m = OLD_FILE_PATTERN.match(line)) || (m = NEW_FILE_PATTERN.match(line))
              name = m[1]
              name = name.split('/').drop(strip_path).join('/') if strip_path
              if file.nil? || file[:name] != name
                file = (files[name] ||= { name: name, chunks: [] })
              end
            elsif (m = CHUNK_PATTERN.match(line))
              old_begin = m[1].to_i
              old_end = old_begin + (m[2].nil? ? 1 : m[2].to_i)
              new_begin = m[3].to_i
              new_end = new_begin + (m[4].nil? ? 1 : m[4].to_i)
              chunk = {
                old_begin: old_begin - 1,
                old_end: old_end - 1,
                new_begin: new_begin - 1,
                new_end: new_end - 1,
                lines: []
              }
              file[:chunks] << chunk
            elsif (m = ADDED_PATTERN.match(line))
              chunk[:lines] << [:added, m[1]]
            elsif (m = REMOVED_PATTERN.match(line))
              chunk[:lines] << [:removed, m[1]]
            elsif (m = UNCHANGED_PATTERN.match(line))
              chunk[:lines] << [:unchanged, m[1]]
            end
          end

          files.each_value do |f|
            patched_file = File.join(path, f[:name])
            lines = IO.readlines(patched_file)
            new_lines = []
            last_src = 0

            f[:chunks].each do |c|
              ob = c[:old_begin]
              new_lines += lines[last_src..ob - 1] if last_src < ob
              last_src = ob
              raise 'error applying patch' unless new_lines.size == c[:new_begin]

              c[:lines].each do |line|
                type, line = line
                case type
                when :added
                  new_lines << line
                when :removed
                  raise 'error applying patch' unless lines[last_src] == line
                  last_src += 1
                when :unchanged
                  raise 'error applying patch' unless lines[last_src] == line
                  last_src += 1
                  new_lines << line
                else
                  raise 'internal error'
                end
              end
            end

            new_lines += lines[last_src..lines.size - 1] if last_src < lines.size

            File.open(patched_file, 'w') do |of|
              new_lines.each { |l| of.print(l) }
            end
          end
        end
      end
    end
  end
end
