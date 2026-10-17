# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Invoices: create, calculate, get, list, iterate, events, pdf, xml,
    # download_url, send_email.
    class Invoices < Base
      INVOICE_MAPPER = ->(item) { Types::Invoice.from_wire(item) }
      EVENT_MAPPER = ->(item) { Types::InvoiceEvent.from_wire(item) }

      def create(params, idempotency_key: nil)
        @t.request(
          "POST", "/invoices",
          json: params,
          idempotency_key: idempotency_key,
          type: Types::Invoice
        )
      end

      # Estimate the taxes without issuing, storing or charging anything.
      # Same body as +create+. A fiscal gap is not an error: the result has
      # +"status" => "blocked"+ with +"blocking"+ and +"pendingFields"+. Money
      # values are decimal strings. Returns the parsed JSON (a Hash).
      def calculate(params)
        @t.request("POST", "/invoices/calculate", json: params)
      end

      def get(id)
        @t.request("GET", "/invoices/#{Util.enc(id)}", type: Types::Invoice)
      end

      def list(companyId: nil, status: nil, from: nil, to: nil, externalId: nil, limit: nil, cursor: nil)
        query = {
          companyId: companyId, status: status, from: from, to: to,
          externalId: externalId, limit: limit, cursor: cursor
        }
        @t.list_page("/invoices", query, mapper: INVOICE_MAPPER)
      end

      def iterate(companyId: nil, status: nil, from: nil, to: nil, externalId: nil, limit: nil, cursor: nil, &block)
        query = {
          companyId: companyId, status: status, from: from, to: to,
          externalId: externalId, limit: limit, cursor: cursor
        }
        @t.iterate("/invoices", query, mapper: INVOICE_MAPPER, &block)
      end

      def events(id, limit: nil, cursor: nil)
        @t.list_page(
          "/invoices/#{Util.enc(id)}/events",
          { limit: limit, cursor: cursor },
          mapper: EVENT_MAPPER
        )
      end

      def pdf(id)
        @t.request_raw("GET", "/invoices/#{Util.enc(id)}/pdf")
      end

      def xml(id)
        @t.request_raw("GET", "/invoices/#{Util.enc(id)}/xml")
      end

      def download_url(id, format = "pdf")
        @t.request(
          "POST", "/invoices/#{Util.enc(id)}/download-url",
          json: { format: format },
          type: Types::InvoiceDownloadUrl
        )
      end

      def send_email(id, idempotency_key: nil)
        @t.request(
          "POST", "/invoices/#{Util.enc(id)}/email",
          idempotency_key: idempotency_key,
          type: Types::InvoiceEmailResult
        )
      end
    end
  end
end
