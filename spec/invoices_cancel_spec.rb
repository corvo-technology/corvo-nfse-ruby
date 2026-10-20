# frozen_string_literal: true

RSpec.describe "invoice cancellation" do
  let(:client) { build_client }
  let(:cancel_url) { "#{BASE_URL}/v1/invoices/inv_1/cancel" }

  def invoice_body(attrs)
    { data: { id: "inv_1", companyId: "c_1" }.merge(attrs) }.to_json
  end

  it "exposes the cancellation reasons and every invoice status" do
    expect(CorvoNfse::Types::Invoice::CANCELLATION_REASONS)
      .to eq(%w[issue_error service_not_provided other])
    expect(CorvoNfse::Types::Invoice::STATUSES).to eq(
      %w[queued processing authorized rejected retry_pending reconciliation_required
         manual_review failed cancelling cancelled]
    )
  end

  it "cancel POSTs reason and description and returns the cancelled invoice (200)" do
    stub_request(:post, cancel_url).to_return(
      status: 200,
      body: invoice_body(status: "cancelled", cancellationReason: "issue_error",
                         cancellationDescription: "Valor emitido errado",
                         cancelledAt: "2026-10-20T12:00:00.000Z"),
      headers: json_headers
    )

    data, error = client.invoices.cancel("inv_1", reason: "issue_error", description: "Valor emitido errado")

    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::Invoice)
    expect(data.status).to eq("cancelled")
    expect(data.cancelledAt).to eq("2026-10-20T12:00:00.000Z")
    expect(WebMock).to have_requested(:post, cancel_url)
      .with(
        headers: { "Content-Type" => "application/json" },
        body: { "reason" => "issue_error", "description" => "Valor emitido errado" }
      )
  end

  it "cancel omits description when not given" do
    stub_request(:post, cancel_url)
      .to_return(status: 200, body: invoice_body(status: "cancelled"), headers: json_headers)

    _data, error = client.invoices.cancel("inv_1", reason: "other")

    expect(error).to be_nil
    expect(WebMock).to have_requested(:post, cancel_url).with(body: { "reason" => "other" })
  end

  it "cancel URL-encodes the invoice id" do
    stub_request(:post, "#{BASE_URL}/v1/invoices/inv%2F1/cancel")
      .to_return(status: 200, body: invoice_body(status: "cancelled"), headers: json_headers)

    _data, error = client.invoices.cancel("inv/1", reason: "other")
    expect(error).to be_nil
  end

  it "cancel returns the cancelling invoice on 202" do
    stub_request(:post, cancel_url).to_return(
      status: 202,
      body: invoice_body(status: "cancelling", cancellationReason: "service_not_provided",
                         cancellationDescription: "Servico nao prestado ao cliente",
                         cancellationRequestedAt: "2026-10-20T12:00:00.000Z"),
      headers: json_headers
    )

    data, error = client.invoices.cancel(
      "inv_1", reason: "service_not_provided", description: "Servico nao prestado ao cliente"
    )

    expect(error).to be_nil
    expect(data.status).to eq("cancelling")
    expect(data.cancellationReason).to eq("service_not_provided")
    expect(data.cancellationRequestedAt).to eq("2026-10-20T12:00:00.000Z")
    expect(data.cancelledAt).to be_nil
  end

  it "cancel returns a processing invoice with cancellationRequestedAt on 202" do
    stub_request(:post, cancel_url).to_return(
      status: 202,
      body: invoice_body(status: "processing", cancellationRequestedAt: "2026-10-20T12:00:00.000Z"),
      headers: json_headers
    )

    data, error = client.invoices.cancel("inv_1", reason: "issue_error", description: "Emitida em duplicidade")

    expect(error).to be_nil
    expect(data.status).to eq("processing")
    expect(data.cancellationRequestedAt).to eq("2026-10-20T12:00:00.000Z")
  end

  it "cancel surfaces 409 ERROR_INVOICE_NOT_CANCELLABLE as a CorvoApiError" do
    stub_request(:post, cancel_url).to_return(
      status: 409,
      body: { code: "ERROR_INVOICE_NOT_CANCELLABLE", message: "Invoice cannot be cancelled" }.to_json,
      headers: json_headers
    )

    data, error = client.invoices.cancel("inv_1", reason: "other")

    expect(data).to be_nil
    expect(error).to be_a(CorvoNfse::CorvoApiError)
    expect(error.status).to eq(409)
    expect(error.code).to eq("ERROR_INVOICE_NOT_CANCELLABLE")
  end

  it "cancel surfaces 422 as a CorvoApiError" do
    stub_request(:post, cancel_url).to_return(
      status: 422,
      body: { code: "ERROR_VALIDATION", message: "description must have 15-255 characters" }.to_json,
      headers: json_headers
    )

    data, error = client.invoices.cancel("inv_1", reason: "other", description: "short")

    expect(data).to be_nil
    expect(error.status).to eq(422)
    expect(error.code).to eq("ERROR_VALIDATION")
  end

  it "get parses a cancelled invoice with the cancellation fields" do
    stub_request(:get, "#{BASE_URL}/v1/invoices/inv_1").to_return(
      status: 200,
      body: invoice_body(status: "cancelled", cancellationReason: "issue_error",
                         cancellationDescription: "Valor emitido errado",
                         cancelledAt: "2026-10-20T12:05:00.000Z",
                         cancellationRequestedAt: "2026-10-20T12:00:00.000Z"),
      headers: json_headers
    )

    data, error = client.invoices.get("inv_1")

    expect(error).to be_nil
    expect(data).to be_a(CorvoNfse::Types::Invoice)
    expect(data.status).to eq("cancelled")
    expect(data.cancellationReason).to eq("issue_error")
    expect(data.cancellationDescription).to eq("Valor emitido errado")
    expect(data.cancelledAt).to eq("2026-10-20T12:05:00.000Z")
    expect(data.cancellationRequestedAt).to eq("2026-10-20T12:00:00.000Z")
  end

  it "get parses a cancelling invoice" do
    stub_request(:get, "#{BASE_URL}/v1/invoices/inv_1").to_return(
      status: 200,
      body: invoice_body(status: "cancelling", cancellationReason: "other",
                         cancellationDescription: nil, cancelledAt: nil,
                         cancellationRequestedAt: "2026-10-20T12:00:00.000Z"),
      headers: json_headers
    )

    data, error = client.invoices.get("inv_1")

    expect(error).to be_nil
    expect(data.status).to eq("cancelling")
    expect(data.cancellationReason).to eq("other")
    expect(data.cancellationDescription).to be_nil
    expect(data.cancelledAt).to be_nil
    expect(data.cancellationRequestedAt).to eq("2026-10-20T12:00:00.000Z")
  end

  it "get of an invoice without cancellation fields leaves them nil" do
    stub_request(:get, "#{BASE_URL}/v1/invoices/inv_1")
      .to_return(status: 200, body: invoice_body(status: "authorized"), headers: json_headers)

    data, error = client.invoices.get("inv_1")

    expect(error).to be_nil
    expect(data.cancellationReason).to be_nil
    expect(data.cancelledAt).to be_nil
  end
end
