require_relative 'bundle_provider'

module Grably
  module Libs
    class BitbucketProvider < BundleProvider # :nodoc:
      include Provider

      def initialize(p = {})
        super('bitbucket', p) do |project, revision|
          "https://bitbucket.org/#{project}/get/#{revision}.tar.gz"
        end
      end

      def self.config_var
        'bitbucket'
      end
    end
  end
end
