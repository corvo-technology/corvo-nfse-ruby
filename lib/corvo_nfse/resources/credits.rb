# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Credits — balance, plans, history, iterate_history.
    class Credits < Base
      PLAN_MAPPER = ->(item) do
        props = item.is_a?(Hash) ? item["props"] : nil
        Types::CreditPlan.from_wire(props || item)
      end

      TX_MAPPER = ->(item) do
        props = item.is_a?(Hash) ? item["props"] : nil
        Types::CreditTransaction.from_wire(props || item)
      end

      def balance
        @t.request("GET", "/credits", type: Types::CreditBalance)
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
