# frozen_string_literal: true

module CorvoNfse
  module Types
    # Current credit balance for the tenant.
    CreditBalance = define_data(
      :tenantId, :balance, :overageUnits, :overageAmountCents, :hardLimit
    )

    # A purchasable credit plan.
    CreditPlan = define_data(
      :id, :slug, :name, :description, :monthlyCreditAllowance, :dailyLimit,
      :maxActiveCompanies,
      :creditUnitPriceCents, :throughputRps, :includesWebhooks,
      :includesXmlDownload, :includesPdfDownload, :includesApiKeys,
      :supportTier, :active, :createdAt, :updatedAt
    )

    # A credit ledger transaction. +amount+ is in credits (not BRL); members
    # ending in +Cents+ are in centavos.
    CreditTransaction = define_data(
      :id, :tenantId, :type, :amount, :description, :source, :amountBrlCents,
      :unitPriceCentsApplied, :planIdSnapshot, :reservedInvoiceId, :periodId,
      :isReservation, :relatedTransactionId, :createdAt
    )

    # A public price catalog entry (+GET /plans+), prices in centavos.
    PlanQuote = define_data(
      :slug, :name, :monthlyAllowance, :basePriceCents, :perCreditOverageCents,
      :monthlyTotalCents, :currency
    )

    # The plan recommended for a monthly volume (+GET /plans/quote+). The wire
    # names are snake_case.
    PlanRecommendation = define_data(
      :volume, :recommended_plan, :plan_name, :monthly_allowance,
      :overage_credits, :overage_cost_cents, :base_price_cents,
      :total_estimated_cents, :currency, :billing_cycle
    )
  end
end
