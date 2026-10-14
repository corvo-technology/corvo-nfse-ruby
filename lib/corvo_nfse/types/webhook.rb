# frozen_string_literal: true

module CorvoNfse
  module Types
    # A registered webhook endpoint.
    Webhook = define_data(:id, :url, :events, :active, :createdAt, :updatedAt)

    # A webhook as returned once at creation — includes the signing +secret+.
    WebhookWithSecret = define_data(
      :id, :url, :events, :active, :createdAt, :updatedAt, :secret
    )

    # One delivery attempt record for a webhook.
    WebhookDelivery = define_data(
      :id, :tenantId, :webhookConfigId, :eventType, :environment, :url, :payload,
      :statusCode, :responseBody, :errorMessage, :status, :durationMs,
      :retryCount, :nextRetryAt, :lastError, :createdAt
    )

    # Aggregated delivery counters over a recent window.
    WebhookDeliveryStats = define_data(
      :total, :sent, :failed, :pending, :delayed
    )
  end
end
