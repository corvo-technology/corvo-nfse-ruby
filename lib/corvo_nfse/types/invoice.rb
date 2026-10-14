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
      :stage
    )

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
