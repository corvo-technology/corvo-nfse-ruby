# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Invoices: create, create_batch, calculate, get, list, iterate, events,
    # pdf, xml, download_url, send_email, cancel, substitute, overview, review.
    class Invoices < Base
      INVOICE_MAPPER = ->(item) { Types::Invoice.from_wire(item) }
      EVENT_MAPPER = ->(item) { Types::InvoiceEvent.from_wire(item) }

      # Issue an invoice, or schedule one.
      #
      # With +options.type+ IMMEDIATE (the default) the result is a
      # Types::Invoice (202, status "queued"). With SCHEDULE or RECURRING it is
      # a Types::Schedule (snake_case fields): the note only exists when the
      # schedule runs (09:00 America/Sao_Paulo, Monday to Friday) and
      # +competenceDate+ is the date of the first run, from tomorrow on. RECURRING
      # needs +options.recurrence+ ({ frequency: "WEEKLY"|"BIWEEKLY"|"MONTHLY",
      # endsOn: }). Follow the runs with +schedules.runs+.
      def create(params, idempotency_key: nil)
        data, error = @t.request(
          "POST", "/invoices",
          json: params,
          idempotency_key: idempotency_key
        )
        return [nil, error] if error
        return [nil, nil] if data.nil?

        mapped = data.is_a?(Hash) && data.key?("anchor_on") ? Types::Schedule : Types::Invoice
        [mapped.from_wire(data), nil]
      end

      # Issue 1 to 50 invoices in one call, for one company or several.
      #
      # Each item takes the fields of +create+ plus an optional
      # +idempotencyKey+ (up to 255 characters); the Idempotency-Key header is
      # not used by this route. Items are checked one by one: valid ones are
      # saved together, invalid ones come back "rejected" and are not saved.
      # Match each result's +index+ to the item you sent, fix only the
      # rejected ones and send them again.
      def create_batch(invoices)
        @t.request(
          "POST", "/invoices/batches",
          json: { invoices: invoices },
          type: Types::InvoiceBatchSummary
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

      # +customerTaxId+ filters by the customer's CPF or CNPJ (digits).
      def list(companyId: nil, status: nil, from: nil, to: nil, externalId: nil,
               customerTaxId: nil, limit: nil, cursor: nil)
        query = {
          companyId: companyId, status: status, from: from, to: to,
          externalId: externalId, customerTaxId: customerTaxId,
          limit: limit, cursor: cursor
        }
        @t.list_page("/invoices", query, mapper: INVOICE_MAPPER)
      end

      def iterate(companyId: nil, status: nil, from: nil, to: nil, externalId: nil,
                  customerTaxId: nil, limit: nil, cursor: nil, &block)
        query = {
          companyId: companyId, status: status, from: from, to: to,
          externalId: externalId, customerTaxId: customerTaxId,
          limit: limit, cursor: cursor
        }
        @t.iterate("/invoices", query, mapper: INVOICE_MAPPER, &block)
      end

      # Counters and recent invoices of the tenant and environment. +period+
      # is "7d" (default) or "30d".
      def overview(period: nil)
        @t.request("GET", "/invoices/overview", query: { period: period }, type: Types::InvoiceOverview)
      end

      # Replace an authorized invoice with a corrected one. Only +description+
      # (why, required), +service.description+, +purchaseOrder+ and +notes+ can
      # change. The result is the new invoice (202, queued).
      def substitute(id, params, idempotency_key: nil)
        @t.request(
          "POST", "/invoices/#{Util.enc(id)}/substitute",
          json: params,
          idempotency_key: idempotency_key,
          type: Types::Invoice
        )
      end

      # Resolve invoices in +manual_review+ (up to 100): +action+ is "retry" or
      # "discard". The result has one +results+ entry (id, outcome) per invoice.
      def review(invoice_ids:, action:)
        @t.request(
          "POST", "/invoices/review",
          json: { invoiceIds: invoice_ids, action: action },
          type: Types::InvoiceReviewResult
        )
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

      # Cancel an invoice. +reason+ is "issue_error", "service_not_provided"
      # or "other". +description+ (15 to 255 characters) is required to cancel
      # an authorized or processing invoice and optional for a queued one.
      #
      # A queued invoice is cancelled at once (status "cancelled"); an
      # authorized one moves to "cancelling" while the cancellation is
      # processed, and a processing one stays "processing" with
      # +cancellationRequestedAt+ set. Call +get+ later: "cancelled" when done,
      # or back to "authorized" with +lastErrorCode+ when it was rejected.
      def cancel(id, reason:, description: nil)
        body = { reason: reason }
        body[:description] = description unless description.nil?
        @t.request(
          "POST", "/invoices/#{Util.enc(id)}/cancel",
          json: body,
          type: Types::Invoice
        )
      end

      # Send the invoice e-mail to the customer, or to +email+ instead.
      def send_email(id, email: nil, idempotency_key: nil)
        @t.request(
          "POST", "/invoices/#{Util.enc(id)}/email",
          json: email.nil? ? nil : { email: email },
          idempotency_key: idempotency_key,
          type: Types::InvoiceEmailResult
        )
      end
    end
  end
end
