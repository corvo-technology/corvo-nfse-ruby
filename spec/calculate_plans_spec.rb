# frozen_string_literal: true

RSpec.describe "invoices.calculate and plans" do
  let(:client) { build_client }

  it "calculate returns the estimate and omits a missing customer" do
    stub_request(:post, "#{BASE_URL}/v1/invoices/calculate")
      .to_return(
        status: 200,
        body: {
          data: {
            preEmission: true, status: "ready",
            taxes: {
              iss: { base: "15000.00", rate: "3", amount: "450.00" },
              ibsTotal: { base: "14550.00", amount: "14.55" }
            },
            netReceivableAmount: "15000.00", blocking: nil
          }
        }.to_json,
        headers: json_headers
      )

    data, error = client.invoices.calculate(
      companyTaxId: "11222333000181", service: {}, amount: 15_000, competenceDate: "2026-10-16"
    )

    expect(error).to be_nil
    expect(data["status"]).to eq("ready")
    expect(data["taxes"]["iss"]["amount"]).to eq("450.00")
    expect(data["taxes"]["ibsTotal"]).not_to have_key("rate")
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/invoices/calculate")
      .with { |req| !JSON.parse(req.body).key?("customer") }
  end

  it "calculate returns a blocked estimate as data, not as an error" do
    stub_request(:post, "#{BASE_URL}/v1/invoices/calculate")
      .to_return(
        status: 200,
        body: { data: { status: "blocked", blocking: { code: "TAX_RATE_NOT_FOUND", message: "x", step: "s" } } }.to_json,
        headers: json_headers
      )
    data, error = client.invoices.calculate(service: {}, amount: 10, competenceDate: "2026-10-16")
    expect(error).to be_nil
    expect(data["blocking"]["code"]).to eq("TAX_RATE_NOT_FOUND")
  end

  it "plans list, get and quote hit the public catalog" do
    stub_request(:get, "#{BASE_URL}/v1/plans")
      .with(query: { "limit" => "5" })
      .to_return(status: 200, body: { data: [{ slug: "developer", monthlyAllowance: 200 }],
                                      pagination: { limit: 5, hasMore: false, nextCursor: nil } }.to_json,
                 headers: json_headers)
    stub_request(:get, "#{BASE_URL}/v1/plans/growth")
      .to_return(status: 200, body: { data: { slug: "growth", monthlyTotalCents: 8990 } }.to_json, headers: json_headers)
    stub_request(:get, "#{BASE_URL}/v1/plans/quote")
      .with(query: { "volume" => "20000" })
      .to_return(status: 200, body: { data: { recommended_plan: "volume", total_estimated_cents: 179_990 } }.to_json,
                 headers: json_headers)
    stub_request(:get, "#{BASE_URL}/v1/plans/quote")
      .with(query: { "volume" => "0" })
      .to_return(status: 200, body: { data: nil }.to_json, headers: json_headers)

    page, perr = client.plans.list(limit: 5)
    expect(perr).to be_nil
    expect(page.data.first).to be_a(CorvoNfse::Types::PlanQuote)
    expect(page.data.first.slug).to eq("developer")

    plan, gerr = client.plans.get("growth")
    expect(gerr).to be_nil
    expect(plan.monthlyTotalCents).to eq(8990)

    quote, qerr = client.plans.quote(20_000)
    expect(qerr).to be_nil
    expect(quote).to be_a(CorvoNfse::Types::PlanRecommendation)
    expect(quote.recommended_plan).to eq("volume")

    none, nerr = client.plans.quote(0)
    expect(nerr).to be_nil
    expect(none).to be_nil
  end

  it "exposes the eleven subscribable webhook events" do
    expect(CorvoNfse::Webhooks::EVENTS.length).to eq(11)
    expect(CorvoNfse::Webhooks::EVENTS).to include("nfse.invoice.fiscal_discrepancy", "nfse.invoice.cancelled", "nfse.invoice.cancellation_rejected")
    expect(CorvoNfse::Webhooks::EVENTS).not_to include("webhook.test")
  end
end
