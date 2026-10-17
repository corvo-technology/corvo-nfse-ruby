# frozen_string_literal: true

module CorvoNfse
  module Types
    # ``GET /billing/plan`` payload. The nested +plan+, +subscription+ and
    # +usage+ objects use snake_case wire keys and are returned as raw wire
    # hashes under those members (pass-through, never re-cased).
    BillingPlanResponse = define_data(:plan, :subscription, :usage)

    # ``GET /billing/usage`` payload (camelCase wire keys).
    QuotaStatus = define_data(
      :canEmit, :creditsRemaining, :creditsUsed, :creditsReserved,
      :monthlyAllowance, :dailyUsage, :dailyLimit, :activeCompanies,
      :maxActiveCompanies, :periodStart, :periodEnd, :reason
    )
  end
end
