require "bundler"
Bundler.setup
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w(-I lib/)
end

task :default => :spec

