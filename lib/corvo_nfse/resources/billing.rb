# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Billing — plan, usage.
    class Billing < Base
      # Plan, subscription and usage (snake_case). 404 +NO_PLAN_ASSIGNED+ when
      # the workspace has no plan. +subscription+ has +stripe_portal_available+,
      # +stripe_subscription+ and +pix_subscription+; +usage+ has +avulso_balance+.
      def plan
        @t.request("GET", "/billing/plan", type: Types::BillingPlanResponse)
      end

      def usage
        @t.request("GET", "/billing/usage", type: Types::QuotaStatus)
      end
    end
  end
end
