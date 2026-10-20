# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Invoices: create, calculate, get, list, iterate, events, pdf, xml,
    # download_url, send_email, cancel.
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

      # Request the cancellation of an invoice. Returns the updated
      # Types::Invoice, like +get+.
      #
      # +reason+ is one of Types::Invoice::CANCELLATION_REASONS
      # (+"issue_error"+, +"service_not_provided"+, +"other"+). +description+
      # is optional for a +queued+ invoice and required (15-255 characters) once
      # it is +processing+ or +authorized+; the API validates it (HTTP 422).
      #
      # - +queued+: cancelled at once, +status == "cancelled"+ (HTTP 200).
      # - +authorized+: +status == "cancelling"+ while the Sefin processes the
      #   event (HTTP 202). Check the outcome later with +get+: +"cancelled"+
      #   when done, back to +"authorized"+ with +lastErrorMessage+ if rejected.
      # - +processing+: stays +"processing"+ with +cancellationRequestedAt+ set
      #   (HTTP 202).
      #
      # +retry_pending+, +reconciliation_required+ and +manual_review+ invoices
      # return a CorvoApiError with +code == "ERROR_INVOICE_NOT_CANCELLABLE"+
      # (HTTP 409). Repeating the call returns the current state.
      #
      #   invoice, error = client.invoices.cancel("inv_1", reason: "issue_error",
      #                                           description: "Valor emitido com erro")
      def cancel(id, reason:, description: nil)
        body = { reason: reason }
        body[:description] = description unless description.nil?
        @t.request(
          "POST", "/invoices/#{Util.enc(id)}/cancel",
          json: body,
          type: Types::Invoice
        )
      end
    end
  end
end
