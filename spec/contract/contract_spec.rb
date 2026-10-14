# frozen_string_literal: true

# Live contract tests against a real Corvo environment. They run only when both
# CORVO_API_KEY and CORVO_BASE_URL are set (e.g. in a gated CI job); otherwise
# every example is skipped so the default suite stays hermetic.
RSpec.describe "contract", :contract do
  before do
    unless ENV["CORVO_API_KEY"] && ENV["CORVO_BASE_URL"]
      skip "set CORVO_API_KEY and CORVO_BASE_URL to run contract tests"
    end
  end

  let(:client) do
    CorvoNfse::Client.new(api_key: ENV["CORVO_API_KEY"], base_url: ENV["CORVO_BASE_URL"])
  end

  it "reports live health" do
    data, error = client.health.live
    expect(error).to be_nil
    expect(data).not_to be_nil
  end

  it "reports ready health" do
    data, error = client.health.ready
    expect(error).to be_nil
    expect(data).not_to be_nil
  end

  it "lists companies (limit 1)" do
    page, error = client.companies.list(limit: 1)
    expect(error).to be_nil
    expect(page.data).to be_an(Array)
  end

  it "reads billing usage" do
    data, error = client.billing.usage
    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::QuotaStatus)
  end

  it "reads credit balance" do
    data, error = client.credits.balance
    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::CreditBalance)
  end
end
