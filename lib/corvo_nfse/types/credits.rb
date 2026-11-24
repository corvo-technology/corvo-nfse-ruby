# frozen_string_literal: true

module CorvoNfse
  module Types
    # Current credit balance for the tenant. +balance+ is the plan notes left
    # (+planRemaining+) plus the loose notes bought separately (+avulsoBalance+);
    # plan notes of a lapsed plan count 0. There is no overage billing.
    CreditBalance = define_data(
      :balance, :planRemaining, :avulsoBalance, :hardLimit
    )

    # Price of a one-off purchase of +units+ notes (+GET /credits/purchase/preview+).
    # Buying is done in the dashboard.
    PurchasePreview = define_data(:units, :unitPriceCents, :totalCents)

    # A plan (+GET /credits/plans+). +slug+ is an open string (today: free,
    # self-hosted, solo, equipe, empresa, escala): read the allowances from the
    # plan instead of hard-coding the list.
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

    # A public price of a paid plan (+GET /plans+, +GET /plans/{slug}+), prices
    # in centavos for the chosen billing cycle.
    PlanPrice = define_data(
      :slug, :name, :monthlyAllowance, :basePriceCents, :monthlyEquivalentCents,
      :chargeTotalCents, :currency
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
