require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

require 'grably/lib'

RSpec::Core::RakeTask.new(:spec)

task :default => :check

# Code quality
# Linter
RuboCop::RakeTask.new(:lint) do |t|
  t.options = %w(-S -D)
end

task :test => :spec

desc 'Run lint and tests'
task :check => %i(test lint)

namespace :deps do
  task :install do
    run %w(gem install bundler)
    run %w(bundle)
  end
end
