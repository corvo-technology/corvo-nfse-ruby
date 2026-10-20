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
      :stage, :scheduledFor, :cancellationReason, :cancellationDescription,
      :cancelledAt, :cancellationRequestedAt
    )

    # Every value of +Invoice#status+. +cancelling+ means the Sefin is
    # processing a cancellation; +cancelled+ is final.
    Invoice::STATUSES = %w[
      queued processing authorized rejected retry_pending
      reconciliation_required manual_review failed cancelling cancelled
    ].freeze

    # Accepted +reason+ values for +client.invoices.cancel+ (also the values
    # of +Invoice#cancellationReason+).
    Invoice::CANCELLATION_REASONS = %w[issue_error service_not_provided other].freeze

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
