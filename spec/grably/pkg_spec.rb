require 'bundler/setup'
require 'grably/pkg'

RSpec.describe GrablyPkg do
  it 'has a version number' do
    expect(GrablyPkg::VERSION).not_to be nil
  end
end
