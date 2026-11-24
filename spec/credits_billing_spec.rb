# frozen_string_literal: true

RSpec.describe "credits and billing" do
  let(:client) { build_client }

  it "credits balance is typed" do
    stub_request(:get, "#{BASE_URL}/v1/credits")
      .to_return(status: 200, body: { data: { balance: 110, planRemaining: 100, avulsoBalance: 10, hardLimit: 5000 } }.to_json, headers: json_headers)
    data, error = client.credits.balance
    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::CreditBalance)
    expect(data.balance).to eq(110)
    expect(data.planRemaining).to eq(100)
    expect(data.avulsoBalance).to eq(10)
    expect(data).not_to respond_to(:overageUnits)
  end

  it "credits preview_purchase prices a purchase with GET and units" do
    stub_request(:get, "#{BASE_URL}/v1/credits/purchase/preview")
      .with(query: { "units" => "10" })
      .to_return(status: 200, body: { data: { units: 10, unitPriceCents: 99, totalCents: 990 } }.to_json, headers: json_headers)
    stub_request(:get, "#{BASE_URL}/v1/credits/purchase/preview")
      .with(query: { "units" => "1" })
      .to_return(status: 400, body: { statusCode: 400, code: "ERROR_VALIDATION", message: "units must be at least 3", requestId: "req_1" }.to_json, headers: json_headers)

    data, error = client.credits.preview_purchase(units: 10)
    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::PurchasePreview)
    expect([data.units, data.unitPriceCents, data.totalCents]).to eq([10, 99, 990])

    none, err = client.credits.preview_purchase(units: 1)
    expect(none).to be_nil
    expect(err.status).to eq(400)
    expect(err.code).to eq("ERROR_VALIDATION")
    expect(err.request_id).to eq("req_1")
  end

  it "billing plan reports NO_PLAN_ASSIGNED as the error code" do
    stub_request(:get, "#{BASE_URL}/v1/billing/plan")
      .to_return(status: 404, body: { statusCode: 404, code: "NO_PLAN_ASSIGNED", message: "No plan" }.to_json, headers: json_headers)
    data, error = client.billing.plan
    expect(data).to be_nil
    expect(error.status).to eq(404)
    expect(error.code).to eq("NO_PLAN_ASSIGNED")
  end

  it "credits plans and history return typed items" do
    plans = { data: [{ id: "pl_1", slug: "equipe" }], pagination: { limit: 10, hasMore: false, nextCursor: nil } }
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
    plan_body = { data: { plan: { slug: "solo", monthly_allowance: 100 },
                          subscription: { status: "active", stripe_portal_available: true, stripe_subscription: { id: "sub_1" }, pix_subscription: nil },
                          usage: { credits_used: 5, avulso_balance: 3 } } }
    usage_body = { data: { canEmit: true, creditsRemaining: 42, creditsUsed: 5, creditsReserved: 0, monthlyAllowance: 1000, dailyUsage: 1, dailyLimit: nil, activeCompanies: 1, maxActiveCompanies: 3, periodStart: nil, periodEnd: nil } }
    stub_request(:get, "#{BASE_URL}/v1/billing/plan").to_return(status: 200, body: plan_body.to_json, headers: json_headers)
    stub_request(:get, "#{BASE_URL}/v1/billing/usage").to_return(status: 200, body: usage_body.to_json, headers: json_headers)

    plan, perr = client.billing.plan
    expect(perr).to be_nil
    expect(plan).to be_a(CorvoNfse::Types::BillingPlanResponse)
    expect(plan.plan["slug"]).to eq("solo")
    expect(plan.plan["monthly_allowance"]).to eq(100)
    expect(plan.subscription["stripe_portal_available"]).to be(true)
    expect(plan.usage["avulso_balance"]).to eq(3)
    expect(plan.usage).not_to have_key("overage_units")

    usage, uerr = client.billing.usage
    expect(uerr).to be_nil
    expect(usage).to be_a(CorvoNfse::Types::QuotaStatus)
    expect(usage.creditsRemaining).to eq(42)
  end
end
