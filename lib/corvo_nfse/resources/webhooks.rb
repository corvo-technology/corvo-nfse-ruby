# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Nested ``/webhooks/deliveries`` sub-resource.
    class Deliveries < Base
      DELIVERY_MAPPER = ->(item) { Types::WebhookDelivery.from_wire(item) }

      def list(hours: nil, environment: nil, limit: nil, cursor: nil)
        query = { hours: hours, environment: environment, limit: limit, cursor: cursor }
        @t.list_page("/webhooks/deliveries", query, mapper: DELIVERY_MAPPER)
      end

      def iterate(hours: nil, environment: nil, limit: nil, cursor: nil, &block)
        query = { hours: hours, environment: environment, limit: limit, cursor: cursor }
        @t.iterate("/webhooks/deliveries", query, mapper: DELIVERY_MAPPER, &block)
      end

      def stats(hours: nil, environment: nil)
        @t.request(
          "GET", "/webhooks/deliveries/stats",
          query: { hours: hours, environment: environment },
          type: Types::WebhookDeliveryStats
        )
      end

      def retry(delivery_id)
        @t.request("POST", "/webhooks/deliveries/#{Util.enc(delivery_id)}/retry")
      end
    end

    # Webhooks — list, create, remove, test + nested deliveries.
    class Webhooks < Base
      WEBHOOK_MAPPER = ->(item) { Types::Webhook.from_wire(item) }

      attr_reader :deliveries

      def initialize(transport)
        super
        @deliveries = Deliveries.new(transport)
      end

      def list(limit: nil, cursor: nil)
        @t.list_page("/webhooks", { limit: limit, cursor: cursor }, mapper: WEBHOOK_MAPPER)
      end

      def iterate(limit: nil, cursor: nil, &block)
        @t.iterate("/webhooks", { limit: limit, cursor: cursor }, mapper: WEBHOOK_MAPPER, &block)
      end

      # Create a webhook. The +secret+ is returned once, at creation.
      def create(params)
        @t.request("POST", "/webhooks", json: params, type: Types::WebhookWithSecret)
      end

      def remove(id)
        @t.request("DELETE", "/webhooks/#{Util.enc(id)}")
      end

      def test(id)
        @t.request("POST", "/webhooks/#{Util.enc(id)}/test")
      end
    end
  end
end
