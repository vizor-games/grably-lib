require_relative 'commands'

module Grably
  module Libs
    module Provider # :nodoc:
      class << self
        def included(receiver)
          providers << receiver
        end

        def providers
          @providers ||= []
        end
      end
    end
  end
end

require_relative 'providers/file_provider'
require_relative 'providers/http_provider'
require_relative 'providers/github_provider'
