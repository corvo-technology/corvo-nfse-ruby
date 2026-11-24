# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Credits — balance, plans, history, iterate_history, preview_purchase.
    class Credits < Base
      PLAN_MAPPER = ->(item) { Types::CreditPlan.from_wire(item) }
      TX_MAPPER = ->(item) { Types::CreditTransaction.from_wire(item) }

      def balance
        @t.request("GET", "/credits", type: Types::CreditBalance)
      end

      # Price a one-off purchase of +units+ notes (R$ 0,99 each, at least 3,
      # whole numbers). Buying is done in the dashboard.
      def preview_purchase(units:)
        @t.request(
          "GET", "/credits/purchase/preview",
          query: { units: units },
          type: Types::PurchasePreview
        )
      end

      def plans(limit: nil, cursor: nil)
        @t.list_page("/credits/plans", { limit: limit, cursor: cursor }, mapper: PLAN_MAPPER)
      end

      def history(limit: nil, cursor: nil)
        @t.list_page("/credits/history", { limit: limit, cursor: cursor }, mapper: TX_MAPPER)
      end

      def iterate_history(limit: nil, cursor: nil, &block)
        @t.iterate("/credits/history", { limit: limit, cursor: cursor }, mapper: TX_MAPPER, &block)
      end
    end
  end
end
