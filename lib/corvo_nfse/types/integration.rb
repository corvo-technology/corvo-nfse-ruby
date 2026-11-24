# frozen_string_literal: true

module CorvoNfse
  module Types
    # A payment platform Corvo can connect to. +credentialFields+ and
    # +webhookInstructions+ stay raw wire values.
    IntegrationProvider = define_data(
      :id, :name, :version, :supportedFlows, :credentialFields, :webhookInstructions
    )

    # A connection to a payment platform. +state+: draft, active, paused,
    # reauth_required or disconnected.
    IntegrationConnection = define_data(
      :id, :companyId, :provider, :environment, :state, :activeFrom,
      :externalAccountId, :webhookUrl, :createdAt
    )

    # A connection as returned once at creation: +secrets+ (a Hash) holds the
    # credentials the platform needs, shown only in this response.
    IntegrationConnectionCreated = define_data(
      :id, :companyId, :provider, :environment, :state, :activeFrom,
      :externalAccountId, :webhookUrl, :createdAt, :secrets
    )

    # A rule that turns sales into invoices. +service+ is the raw service body.
    IntegrationRule = define_data(
      :id, :externalProductId, :service, :sendEmail, :cancelOnRefund,
      :allowAnonymousCustomer
    )

    # An event received for a connection. +state+: received, processing,
    # retry_pending, processed, ignored, needs_attention or dead.
    IntegrationEvent = define_data(
      :id, :deliveryId, :externalType, :state, :attempts, :lastError,
      :operationId, :createdAt
    )

    # A sale and the status of its invoice. +customer+ is a raw hash (or nil).
    IntegrationOperation = define_data(
      :id, :operationKey, :commercialState, :fiscalStatus, :blockReason,
      :amountCents, :currency, :customer, :invoiceId, :paidAt, :createdAt,
      :updatedAt
    )

    # Answer of +integration_operations.retry+. +state+: processed, ignored or
    # needs_attention.
    IntegrationOperationRetry = define_data(:operationId, :state, :lastError)
  end
end
