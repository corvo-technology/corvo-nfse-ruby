# frozen_string_literal: true

RSpec.describe "invoices" do
  let(:client) { build_client }
  let(:invoice) { { id: "inv_1", companyId: "c_1", status: "authorized", accessKey: "35260" } }

  it "create unwraps data.props, sends camelCase body and Idempotency-Key" do
    stub_request(:post, "#{BASE_URL}/v1/invoices")
      .to_return(status: 201, body: { data: { props: invoice } }.to_json, headers: json_headers)

    params = { customer: { name: "ACME" }, service: { code: "0101" }, amount: 10.5, competenceDate: "2026-10-01" }
    data, error = client.invoices.create(params, idempotency_key: "idem_1")

    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::Invoice)
    expect(data.id).to eq("inv_1")
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/invoices")
      .with(
        headers: { "Idempotency-Key" => "idem_1" },
        body: { "customer" => { "name" => "ACME" }, "service" => { "code" => "0101" }, "amount" => 10.5, "competenceDate" => "2026-10-01" }
      )
  end

  it "list maps props items and events maps props items" do
    page = { data: [{ props: invoice }], pagination: { limit: 5, hasMore: false, nextCursor: nil } }
    events = { data: [{ props: { id: "evt_1", invoiceId: "inv_1", toStatus: "authorized" } }],
               pagination: { limit: 5, hasMore: false, nextCursor: nil } }
    stub_request(:get, "#{BASE_URL}/v1/invoices")
      .with(query: { "companyId" => "c_1", "status" => "authorized", "limit" => "5" })
      .to_return(status: 200, body: page.to_json, headers: json_headers)
    stub_request(:get, "#{BASE_URL}/v1/invoices/inv_1/events")
      .with(query: { "limit" => "5" })
      .to_return(status: 200, body: events.to_json, headers: json_headers)

    list, error = client.invoices.list(companyId: "c_1", status: "authorized", limit: 5)
    expect(error).to be_nil
    expect(list.data.first).to be_a(CorvoNfse::Types::Invoice)
    expect(list.data.first.id).to eq("inv_1")

    ev_page, eerr = client.invoices.events("inv_1", limit: 5)
    expect(eerr).to be_nil
    expect(ev_page.data.first).to be_a(CorvoNfse::Types::InvoiceEvent)
    expect(ev_page.data.first.toStatus).to eq("authorized")
  end

  it "pdf/xml return a DownloadedFile and download_url/send_email return typed results" do
    stub_request(:get, "#{BASE_URL}/v1/invoices/inv_1/pdf")
      .to_return(status: 200, body: "%PDF", headers: { "Content-Type" => "application/pdf", "Content-Disposition" => 'attachment; filename="inv_1.pdf"' })
    stub_request(:post, "#{BASE_URL}/v1/invoices/inv_1/download-url")
      .to_return(status: 200, body: { data: { downloadUrl: "https://cdn/x.pdf", expiresAt: "2026-10-02" } }.to_json, headers: json_headers)
    stub_request(:post, "#{BASE_URL}/v1/invoices/inv_1/email")
      .to_return(status: 200, body: { data: { emailId: "em_1", status: "queued" } }.to_json, headers: json_headers)

    file, ferr = client.invoices.pdf("inv_1")
    expect(ferr).to be_nil
    expect(file).to be_a(CorvoNfse::Types::DownloadedFile)
    expect(file.content).to eq("%PDF")
    expect(file.file_name).to eq("inv_1.pdf")

    du, duerr = client.invoices.download_url("inv_1", "pdf")
    expect(duerr).to be_nil
    expect(du.downloadUrl).to eq("https://cdn/x.pdf")

    mail, merr = client.invoices.send_email("inv_1")
    expect(merr).to be_nil
    expect(mail.status).to eq("queued")
  end
end
