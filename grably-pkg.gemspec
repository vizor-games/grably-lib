require_relative "lib/grably/pkg/version"

Gem::Specification.new do |s|
  s.name        = 'grably-pkg'
  s.version     = Grably::Pkg.version
  s.summary     = 'Grably extension for managing packages (artifacts). Experimental.'
  s.licenses    = ['Apache-2.0']
  s.homepage    = 'https://github.com/vizor-games/grably-pkg'

  s.authors     = ['Viktor Kuzmin']
  s.email       = ['kva@vizor-interactive.com']

  s.bindir      = 'exe'
  s.executables = Dir['exe/*'].map { |e| File.basename(e) }
  s.metadata    = {
    'source_code_uri' => 'https://github.com/vizor-games/grably-pkg'
  }


end
