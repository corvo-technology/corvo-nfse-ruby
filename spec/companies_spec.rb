# frozen_string_literal: true

RSpec.describe "companies" do
  let(:client) { build_client }
  let(:company) do
    {
      id: "c_1",
      tenantId: "t_1",
      legalName: "Empresa Exemplo LTDA",
      tradeName: "Empresa Exemplo",
      taxId: "41834687000148",
      taxRegime: "Simples Nacional",
      environment: "test",
      status: "ready",
      setupGaps: []
    }
  end

  it "create POSTs /v1/companies with the wire body and returns a Company" do
    stub_request(:post, "#{BASE_URL}/v1/companies")
      .to_return(status: 201, body: { data: company }.to_json, headers: json_headers)

    data, error = client.companies.create(legalName: "Empresa Exemplo LTDA", taxId: "41834687000148")

    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::Company)
    expect(data.id).to eq("c_1")
    expect(data.taxId).to eq("41834687000148")
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/companies")
      .with(body: { "legalName" => "Empresa Exemplo LTDA", "taxId" => "41834687000148" })
  end

  it "list returns a Paginated page of companies" do
    page_body = { data: [company], pagination: { limit: 2, hasMore: false, nextCursor: nil } }
    stub_request(:get, "#{BASE_URL}/v1/companies")
      .with(query: { "limit" => "2" })
      .to_return(status: 200, body: page_body.to_json, headers: json_headers)

    page, error = client.companies.list(limit: 2)
    expect(error).to be_nil
    expect(page.data.length).to eq(1)
    expect(page.data.first).to be_a(CorvoNfse::Types::Company)
    expect(page.pagination.hasMore).to be(false)
  end

  it "iterate walks cursor pages" do
    stub_request(:get, "#{BASE_URL}/v1/companies")
      .with(query: { "limit" => "1" })
      .to_return(
        status: 200,
        body: { data: [{ id: "c_1" }], pagination: { limit: 1, hasMore: true, nextCursor: "cur_1" } }.to_json,
        headers: json_headers
      )
    stub_request(:get, "#{BASE_URL}/v1/companies")
      .with(query: { "limit" => "1", "cursor" => "cur_1" })
      .to_return(
        status: 200,
        body: { data: [{ id: "c_2" }], pagination: { limit: 1, hasMore: false, nextCursor: nil } }.to_json,
        headers: json_headers
      )

    ids = []
    client.companies.iterate(limit: 1) { |c| ids << c.id }
    expect(ids).to eq(%w[c_1 c_2])
  end

  it "iterate raises a CorvoApiError on first-page failure" do
    stub_request(:get, "#{BASE_URL}/v1/companies")
      .to_return(status: 500, body: { code: "SERVER", message: "boom" }.to_json, headers: json_headers)

    expect { client.companies.iterate(limit: 1).to_a }.to raise_error(CorvoNfse::CorvoApiError) do |err|
      expect(err.code).to eq("SERVER")
      expect(err.status).to eq(500)
    end
  end

  it "update PATCHes and remove DELETEs with 204 -> nil" do
    stub_request(:patch, "#{BASE_URL}/v1/companies/c_1")
      .to_return(status: 200, body: { data: company }.to_json, headers: json_headers)
    stub_request(:delete, "#{BASE_URL}/v1/companies/c_1").to_return(status: 204)

    updated, uerr = client.companies.update("c_1", tradeName: "New")
    expect(uerr).to be_nil
    expect(updated).to be_a(CorvoNfse::Types::Company)

    data, error = client.companies.remove("c_1")
    expect(data).to be_nil
    expect(error).to be_nil
  end
end
