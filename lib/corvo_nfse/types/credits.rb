# frozen_string_literal: true

module CorvoNfse
  module Types
    # Current credit balance for the tenant.
    CreditBalance = define_data(
      :tenantId, :balance, :overageUnits, :overageAmountCents, :hardLimit
    )

    # A purchasable credit plan.
    CreditPlan = define_data(
      :id, :slug, :name, :description, :dailyLimit, :maxActiveCompanies,
      :creditUnitPriceCents, :throughputRps, :includesWebhooks,
      :includesXmlDownload, :includesPdfDownload, :includesApiKeys,
      :supportTier, :active, :createdAt, :updatedAt
    )

    # A credit ledger transaction.
    CreditTransaction = define_data(
      :id, :type, :amount, :creditDelta, :balanceAfter, :environment, :source,
      :referenceType, :referenceId, :createdAt
    )
  end
end
