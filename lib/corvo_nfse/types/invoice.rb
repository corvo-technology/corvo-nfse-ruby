# frozen_string_literal: true

module CorvoNfse
  module Types
    # An NFS-e invoice through its lifecycle.
    Invoice = define_data(
      :id, :companyId, :tenantId, :environment, :documentKeyVersion,
      :emailSnapshot, :externalId, :idempotencyKey, :status, :customerSnapshot,
      :serviceSnapshot, :taxSnapshot, :amount, :currency, :competenceDate,
      :dpsId, :dpsSeries, :dpsNumber, :accessKey, :nfseNumber, :fiscalProvider,
      :fiscalSchemaVersion, :issuedAt, :authorizedAt, :lastErrorCode,
      :lastErrorMessage, :lastErrorProvider, :documentsReadyAt, :lastEmailStatus,
      :lastEmailSentAt, :createdAt, :updatedAt, :documentsStatus, :emailStatus,
      :stage, :scheduledFor,
      # Set only when declared on the invoice (BRL).
      :discount, :deduction,
      # Nil until a cancellation is requested.
      :cancellationReason, :cancellationDescription, :cancelledAt,
      :cancellationRequestedAt
    )

    # Outcome of one item of +invoices.create_batch+. +index+ is the item's
    # position in the request (from 0); +status+ is "accepted" (+invoice+ set)
    # or "rejected" (+error+ set: a Hash with "code", "message" and "details";
    # the item was not saved). +replayed+ is true when the item repeated an
    # +idempotencyKey+ already saved with the same content.
    InvoiceBatchResult = define_data(:index, :status, :replayed, :invoice, :error) do
      def self.from_wire(hash)
        return nil if hash.nil?

        src = hash.transform_keys(&:to_sym)
        new(
          index: src[:index], status: src[:status], replayed: src[:replayed],
          invoice: Invoice.from_wire(src[:invoice]), error: src[:error]
        )
      end
    end

    # Result of +invoices.create_batch+: one +results+ entry per item, in the
    # order sent.
    InvoiceBatchSummary = define_data(:total, :accepted, :rejected, :results) do
      def self.from_wire(hash)
        return nil if hash.nil?

        src = hash.transform_keys(&:to_sym)
        new(
          total: src[:total], accepted: src[:accepted], rejected: src[:rejected],
          results: (src[:results] || []).map { |item| InvoiceBatchResult.from_wire(item) }
        )
      end
    end

    # A status transition recorded for an invoice.
    InvoiceEvent = define_data(
      :id, :invoiceId, :fromStatus, :toStatus, :reason, :createdAt
    )

    # A time-limited signed download URL for a generated document.
    InvoiceDownloadUrl = define_data(
      :downloadUrl, :expiresAt, :fileName, :mimeType
    )

    # Result of triggering an invoice e-mail send.
    InvoiceEmailResult = define_data(:emailId, :status)
  end
end
