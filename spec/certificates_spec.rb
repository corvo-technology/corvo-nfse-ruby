# frozen_string_literal: true

RSpec.describe "certificates" do
  let(:client) { build_client }

  it "upload sends multipart and returns a Certificate" do
    cert = { id: "cert_1", companyId: "c_1", serialNumber: "01", status: "active" }
    stub_request(:post, "#{BASE_URL}/v1/companies/c_1/certificates")
      .to_return(status: 201, body: { data: cert }.to_json, headers: json_headers)

    data, error = client.certificates.upload("c_1", "P12BYTES", "secret", file_name: "acme.p12")

    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::Certificate)
    expect(data.id).to eq("cert_1")
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/companies/c_1/certificates").with { |req|
      req.headers["Content-Type"].to_s.start_with?("multipart/form-data") &&
        req.body.include?("P12BYTES") && req.body.include?("secret") && req.body.include?("acme.p12")
    }
  end

  it "list returns certificates and remove DELETEs the certificate" do
    stub_request(:get, "#{BASE_URL}/v1/companies/c_1/certificates")
      .to_return(
        status: 200,
        body: { data: [{ id: "cert_1" }], pagination: { limit: 10, hasMore: false, nextCursor: nil } }.to_json,
        headers: json_headers
      )
    stub_request(:delete, "#{BASE_URL}/v1/companies/c_1/certificates/cert_1").to_return(status: 204)

    page, error = client.certificates.list("c_1")
    expect(error).to be_nil
    expect(page.data.first.id).to eq("cert_1")

    data, rerr = client.certificates.remove("c_1", "cert_1")
    expect(data).to be_nil
    expect(rerr).to be_nil
  end
end
