# frozen_string_literal: true

RSpec.describe "credits and billing" do
  let(:client) { build_client }

  it "credits balance is typed" do
    stub_request(:get, "#{BASE_URL}/v1/credits")
      .to_return(status: 200, body: { data: { tenantId: "t_1", balance: 100, overageUnits: 0, overageAmountCents: 0, hardLimit: nil } }.to_json, headers: json_headers)
    data, error = client.credits.balance
    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::CreditBalance)
    expect(data.balance).to eq(100)
  end

  it "credits plans and history return typed items" do
    plans = { data: [{ id: "pl_1", slug: "starter" }], pagination: { limit: 10, hasMore: false, nextCursor: nil } }
    history = { data: [{ id: "tx_1", type: "usage", amount: -1 }], pagination: { limit: 10, hasMore: false, nextCursor: nil } }
    stub_request(:get, "#{BASE_URL}/v1/credits/plans").to_return(status: 200, body: plans.to_json, headers: json_headers)
    stub_request(:get, "#{BASE_URL}/v1/credits/history").to_return(status: 200, body: history.to_json, headers: json_headers)

    pl, perr = client.credits.plans
    expect(perr).to be_nil
    expect(pl.data.first).to be_a(CorvoNfse::Types::CreditPlan)

    hx, herr = client.credits.history
    expect(herr).to be_nil
    expect(hx.data.first).to be_a(CorvoNfse::Types::CreditTransaction)
  end

  it "billing plan and usage are typed (snake_case / camelCase wire)" do
    plan_body = { data: { plan: { slug: "pro", monthly_allowance: 1000 }, subscription: { status: "active" }, usage: { credits_used: 5 } } }
    usage_body = { data: { canEmit: true, creditsRemaining: 42, creditsUsed: 5, creditsReserved: 0, monthlyAllowance: 1000, dailyUsage: 1, dailyLimit: nil, activeCompanies: 1, maxActiveCompanies: 3, periodStart: nil, periodEnd: nil } }
    stub_request(:get, "#{BASE_URL}/v1/billing/plan").to_return(status: 200, body: plan_body.to_json, headers: json_headers)
    stub_request(:get, "#{BASE_URL}/v1/billing/usage").to_return(status: 200, body: usage_body.to_json, headers: json_headers)

    plan, perr = client.billing.plan
    expect(perr).to be_nil
    expect(plan).to be_a(CorvoNfse::Types::BillingPlanResponse)
    expect(plan.plan["slug"]).to eq("pro")
    expect(plan.plan["monthly_allowance"]).to eq(1000)

    usage, uerr = client.billing.usage
    expect(uerr).to be_nil
    expect(usage).to be_a(CorvoNfse::Types::QuotaStatus)
    expect(usage.creditsRemaining).to eq(42)
  end
end
