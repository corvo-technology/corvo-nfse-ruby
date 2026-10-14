# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Shared constructor for every resource namespace.
    class Base
      def initialize(transport)
        @t = transport
      end
    end
  end
end
