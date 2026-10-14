# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Public health checks (no envelope — the raw body is returned).
    class Health < Base
      def live
        @t.request("GET", "/health/live", unwrap: "none")
      end

      def ready
        @t.request("GET", "/health/ready", unwrap: "none")
      end
    end
  end
end
