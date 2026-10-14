# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Billing — plan, usage.
    class Billing < Base
      def plan
        @t.request("GET", "/billing/plan", type: Types::BillingPlanResponse)
      end

      def usage
        @t.request("GET", "/billing/usage", type: Types::QuotaStatus)
      end
    end
  end
end
