require 'bundler/setup'
require 'grably/libs'

RSpec.describe Grably::Libs do
  it 'has a version number' do
    expect(Grably::Libs::VERSION).not_to be nil
  end
end
