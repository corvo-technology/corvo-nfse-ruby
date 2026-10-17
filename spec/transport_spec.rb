# frozen_string_literal: true

RSpec.describe CorvoNfse::Transport do
  let(:client) { build_client }

  it "unwraps { data } (mode data)" do
    stub_request(:get, "#{BASE_URL}/v1/billing/usage")
      .to_return(status: 200, body: { data: { canEmit: true } }.to_json, headers: json_headers)
    data, error = client.billing.usage
    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::QuotaStatus)
    expect(data.canEmit).to be(true)
  end

  it "returns the resource straight from data" do
    stub_request(:post, "#{BASE_URL}/v1/invoices")
      .to_return(status: 201, body: { data: { id: "inv_1" } }.to_json, headers: json_headers)
    data, error = client.invoices.create({ customer: { name: "A" } })
    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::Invoice)
    expect(data.id).to eq("inv_1")
  end

  it "returns the raw body for health (mode none)" do
    stub_request(:get, "#{BASE_URL}/v1/health/live")
      .to_return(status: 200, body: { status: "ok" }.to_json, headers: json_headers)
    data, error = client.health.live
    expect(error).to be_nil
    expect(data).to eq({ "status" => "ok" })
  end

  it "maps a 204 to nil data / nil error" do
    stub_request(:delete, "#{BASE_URL}/v1/companies/c_1").to_return(status: 204)
    data, error = client.companies.remove("c_1")
    expect(data).to be_nil
    expect(error).to be_nil
  end

  it "maps a 400 error body into a CorvoApiError" do
    body = {
      code: "ERROR_VALIDATION",
      message: "Validation failed",
      requestId: "req_9",
      details: [{ field: "taxId", code: "invalid", message: "bad" }]
    }
    stub_request(:get, "#{BASE_URL}/v1/companies/x")
      .to_return(status: 400, body: body.to_json, headers: json_headers)
    data, error = client.companies.get("x")
    expect(data).to be_nil
    expect(error).to be_a(CorvoNfse::CorvoApiError)
    expect(error.status).to eq(400)
    expect(error.code).to eq("ERROR_VALIDATION")
    expect(error.message).to eq("Validation failed")
    expect(error.request_id).to eq("req_9")
    expect(error.details.first["field"]).to eq("taxId")
  end

  it "falls back to http_<status> code and reads Retry-After header" do
    stub_request(:get, "#{BASE_URL}/v1/companies/x")
      .to_return(status: 429, body: "nope", headers: { "Content-Type" => "text/plain", "Retry-After" => "30" })
    data, error = client.companies.get("x")
    expect(data).to be_nil
    expect(error.code).to eq("http_429")
    expect(error.retry_after).to eq(30)
  end

  it "maps a timeout into a status=0 timeout error" do
    stub_request(:get, "#{BASE_URL}/v1/companies/x").to_timeout
    data, error = client.companies.get("x")
    expect(data).to be_nil
    expect(error.status).to eq(0)
    expect(error.code).to eq("timeout")
  end

  it "maps a socket failure into a network_error" do
    stub_request(:get, "#{BASE_URL}/v1/companies/x").to_raise(SocketError)
    data, error = client.companies.get("x")
    expect(data).to be_nil
    expect(error.status).to eq(0)
    expect(error.code).to eq("network_error")
  end

  it "sends the X-API-Key header (never Authorization)" do
    stub_request(:get, "#{BASE_URL}/v1/companies/x")
      .to_return(status: 200, body: { data: { id: "x" } }.to_json, headers: json_headers)
    client.companies.get("x")
    expect(WebMock).to have_requested(:get, "#{BASE_URL}/v1/companies/x")
      .with(headers: { "X-API-Key" => API_KEY })
    expect(WebMock).not_to have_requested(:get, "#{BASE_URL}/v1/companies/x")
      .with(headers: { "Authorization" => /.+/ })
  end
end
