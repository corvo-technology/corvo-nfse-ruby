# frozen_string_literal: true

RSpec.describe "invoices" do
  let(:client) { build_client }
  let(:invoice) { { id: "inv_1", companyId: "c_1", status: "authorized", accessKey: "35260" } }

  it "create returns the invoice, sends camelCase body and Idempotency-Key" do
    stub_request(:post, "#{BASE_URL}/v1/invoices")
      .to_return(status: 201, body: { data: invoice }.to_json, headers: json_headers)

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

  it "list and events return typed items" do
    page = { data: [invoice], pagination: { limit: 5, hasMore: false, nextCursor: nil } }
    events = { data: [{ id: "evt_1", invoiceId: "inv_1", toStatus: "authorized" }],
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

  it "create_batch posts the items without an Idempotency-Key header and returns typed results" do
    summary = {
      total: 2, accepted: 1, rejected: 1,
      results: [
        { index: 0, status: "accepted", replayed: true, invoice: invoice.merge(deduction: 20) },
        { index: 1, status: "rejected", error: { code: "ERROR_VALIDATION", message: "Request validation failed" } }
      ]
    }
    stub_request(:post, "#{BASE_URL}/v1/invoices/batches")
      .to_return(status: 202, body: { data: summary }.to_json, headers: json_headers)

    item = { companyTaxId: "11222333000181", idempotencyKey: "sheet-row-2", service: { description: "Consultoria" },
             amount: 150.5, deduction: 20, competenceDate: "2026-10-01" }
    data, error = client.invoices.create_batch([item])

    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::InvoiceBatchSummary)
    expect(data.total).to eq(2)
    expect(data.results[0].replayed).to be(true)
    expect(data.results[0].invoice).to be_a(CorvoNfse::Types::Invoice)
    expect(data.results[0].invoice.deduction).to eq(20)
    expect(data.results[1].error["code"]).to eq("ERROR_VALIDATION")
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/invoices/batches")
      .with { |req| JSON.parse(req.body)["invoices"][0]["idempotencyKey"] == "sheet-row-2" && !req.headers.key?("Idempotency-Key") }
  end

  it "cancel posts reason and description and returns the typed invoice" do
    stub_request(:post, "#{BASE_URL}/v1/invoices/inv_1/cancel")
      .to_return(status: 202, body: { data: invoice.merge(status: "cancelling", cancellationReason: "issue_error") }.to_json, headers: json_headers)

    data, error = client.invoices.cancel("inv_1", reason: "issue_error", description: "Wrong amount on the invoice")

    expect(error).to be_nil
    expect(data.status).to eq("cancelling")
    expect(data.cancellationReason).to eq("issue_error")
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/invoices/inv_1/cancel")
      .with(body: { "reason" => "issue_error", "description" => "Wrong amount on the invoice" })
  end

  it "cancel omits the description when not given and returns the typed error" do
    stub_request(:post, "#{BASE_URL}/v1/invoices/inv_1/cancel")
      .to_return(status: 409, body: { statusCode: 409, code: "ERROR_INVOICE_NOT_CANCELLABLE", message: "no" }.to_json, headers: json_headers)

    data, error = client.invoices.cancel("inv_1", reason: "other")

    expect(data).to be_nil
    expect(error.code).to eq("ERROR_INVOICE_NOT_CANCELLABLE")
    expect(WebMock).to have_requested(:post, "#{BASE_URL}/v1/invoices/inv_1/cancel").with(body: { "reason" => "other" })
  end
end
