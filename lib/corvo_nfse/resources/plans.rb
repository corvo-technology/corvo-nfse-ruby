# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Plans: the public price catalog (monthly cycle only). Prices in centavos.
    class Plans < Base
      MAPPER = ->(item) { Types::PlanQuote.from_wire(item) }

      # One page of plan prices, from the smallest to the largest allowance.
      def list(limit: nil, cursor: nil)
        @t.list_page("/plans", { limit: limit, cursor: cursor }, mapper: MAPPER)
      end

      # The price of one plan: free, developer, growth, scale or volume.
      def get(slug)
        @t.request("GET", "/plans/#{Util.enc(slug)}", type: Types::PlanQuote)
      end

      # The plan recommended for +volume+ invoices per month. The data is nil
      # (with no error) when the volume is missing or not positive.
      def quote(volume)
        @t.request("GET", "/plans/quote", query: { volume: volume }, type: Types::PlanRecommendation)
      end
    end
  end
end
