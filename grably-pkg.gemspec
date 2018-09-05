require_relative 'lib/grably/libs/version'

Gem::Specification.new do |s|
  s.name        = 'grably-libs'
  s.version     = Grably::Libs::VERSION
  s.summary     = 'Experimental Grably extension for managing libraries (artifacts).'
  s.licenses    = ['Apache-2.0']
  s.homepage    = 'https://github.com/vizor-games/grably-libs'

  s.authors     = ['Viktor Kuzmin']
  s.email       = ['kva@vizor-interactive.com']

  s.bindir      = 'exe'
  s.executables = Dir['exe/*'].map { |e| File.basename(e) }
  s.metadata    = {
    'source_code_uri' => 'https://github.com/vizor-games/grably-libs'
  }

  s.add_runtime_dependency 'grably'
  s.add_development_dependency 'rspec', '~> 3.5.0'
  s.add_development_dependency 'rubocop', '~> 0.50.0'
end
