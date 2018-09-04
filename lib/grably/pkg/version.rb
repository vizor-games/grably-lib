module Grably
  module Pkg
    # Version identifier
    VERSION = "0.1.0".freeze

    # Version string
    def version
      VERSION.join('.')
    end
  end
end
