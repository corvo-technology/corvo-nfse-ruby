# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Plans: the public price catalog (monthly cycle only). Prices in centavos.
    class Plans < Base
      MAPPER = ->(item) { Types::PlanPrice.from_wire(item) }

      # One page of paid plan prices (public, no API key needed), from the
      # smallest to the largest allowance. +cycle+: monthly (default) or annual.
      def list(limit: nil, cursor: nil, cycle: nil)
        @t.list_page("/plans", { limit: limit, cursor: cursor, cycle: cycle }, mapper: MAPPER)
      end

      # The price of one paid plan: solo, equipe, empresa or escala (public, no
      # API key needed). +cycle+: monthly (default) or annual.
      def get(slug, cycle: nil)
        @t.request("GET", "/plans/#{Util.enc(slug)}", query: { cycle: cycle }, type: Types::PlanPrice)
      end

      # The plan recommended for +volume+ invoices per month. The data is nil
      # (with no error) when the volume is missing or not positive.
      def quote(volume)
        @t.request("GET", "/plans/quote", query: { volume: volume }, type: Types::PlanRecommendation)
      end
    end
  end
end
