# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Payment platforms Corvo can connect to.
    class Integrations < Base
      MAPPER = ->(item) { Types::IntegrationProvider.from_wire(item) }

      # Returns an Array of providers.
      def list_providers
        data, error = @t.request("GET", "/integrations/providers")
        return [nil, error] if error

        [Array(data).map { |item| MAPPER.call(item) }, nil]
      end
    end

    # Connections to payment platforms. A key only sees connections of its own
    # environment (test or live).
    class IntegrationConnections < Base
      CONNECTION_MAPPER = ->(item) { Types::IntegrationConnection.from_wire(item) }
      RULE_MAPPER = ->(item) { Types::IntegrationRule.from_wire(item) }
      EVENT_MAPPER = ->(item) { Types::IntegrationEvent.from_wire(item) }
      OPERATION_MAPPER = ->(item) { Types::IntegrationOperation.from_wire(item) }

      # Returns an Array.
      def list
        list_of("/integrations/connections", CONNECTION_MAPPER)
      end

      # +params+: companyId, provider, credentials (required), environment,
      # activeFrom. The result carries +secrets+, shown only once.
      def create(**params)
        @t.request(
          "POST", "/integrations/connections",
          json: params, type: Types::IntegrationConnectionCreated
        )
      end

      def get(id)
        @t.request("GET", path(id), type: Types::IntegrationConnection)
      end

      # Check the credentials and identify the external account.
      def validate(id)
        @t.request("POST", "#{path(id)}/validate", type: Types::IntegrationConnection)
      end

      # Replace credentials (for example a rotated API key).
      def update_credentials(id, credentials)
        @t.request(
          "PUT", "#{path(id)}/credentials",
          json: { credentials: credentials }, type: Types::IntegrationConnection
        )
      end

      # Start issuing invoices automatically.
      def activate(id)
        @t.request("POST", "#{path(id)}/activate", type: Types::IntegrationConnection)
      end

      # Stop issuing; events are still recorded.
      def pause(id)
        @t.request("POST", "#{path(id)}/pause", type: Types::IntegrationConnection)
      end

      # Disconnect for good.
      def disconnect(id)
        @t.request("POST", "#{path(id)}/disconnect", type: Types::IntegrationConnection)
      end

      # Returns an Array of rules.
      def list_rules(id)
        list_of("#{path(id)}/rules", RULE_MAPPER)
      end

      # Replace every rule of the connection. +rules+ is an Array of rule hashes
      # (service, sendEmail, externalProductId, cancelOnRefund, allowAnonymousCustomer).
      def replace_rules(id, rules)
        data, error = @t.request("PUT", "#{path(id)}/rules", json: { rules: rules })
        return [nil, error] if error

        [Array(data).map { |item| RULE_MAPPER.call(item) }, nil]
      end

      # Recent events received (an Array).
      def list_events(id, limit: nil)
        list_of("#{path(id)}/events", EVENT_MAPPER, limit: limit)
      end

      # Recent operations (sales) and their invoice status (an Array).
      def list_operations(id, limit: nil)
        list_of("#{path(id)}/operations", OPERATION_MAPPER, limit: limit)
      end

      private

      def path(id)
        "/integrations/connections/#{Util.enc(id)}"
      end

      def list_of(url, mapper, limit: nil)
        data, error = @t.request("GET", url, query: { limit: limit })
        return [nil, error] if error

        [Array(data).map { |item| mapper.call(item) }, nil]
      end
    end

    # Operations (sales) of a connection.
    class IntegrationOperations < Base
      # Fill in the customer of an operation waiting for it. +params+: taxId
      # (required), name, email.
      def complete_customer(id, **params)
        @t.request(
          "PATCH", "/integrations/operations/#{Util.enc(id)}/customer",
          json: params, type: Types::IntegrationOperation
        )
      end

      # Try to issue the invoice of the operation again.
      def retry(id)
        @t.request(
          "POST", "/integrations/operations/#{Util.enc(id)}/retry",
          type: Types::IntegrationOperationRetry
        )
      end
    end
  end
end
