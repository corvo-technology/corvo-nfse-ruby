# frozen_string_literal: true

RSpec.describe CorvoNfse::CorvoApiError do
  it "constructs with all fields" do
    err = described_class.new(
      status: 400,
      code: "ERROR_VALIDATION",
      message: "Validation failed",
      details: [{ "field" => "taxId", "code" => "invalid", "message" => "bad" }],
      request_id: "req_1",
      retry_after: 30
    )
    expect(err.status).to eq(400)
    expect(err.code).to eq("ERROR_VALIDATION")
    expect(err.message).to eq("Validation failed")
    expect(err.details).to eq([{ "field" => "taxId", "code" => "invalid", "message" => "bad" }])
    expect(err.request_id).to eq("req_1")
    expect(err.retry_after).to eq(30)
  end

  it "defaults details to [] and optional fields to nil" do
    err = described_class.new(status: 500, code: "SERVER", message: "boom")
    expect(err.details).to eq([])
    expect(err.request_id).to be_nil
    expect(err.retry_after).to be_nil
    expect(err.message).to eq("boom")
  end

  it "is a StandardError (so iterate can raise it)" do
    expect(described_class.ancestors).to include(StandardError)
    expect { raise described_class.new(status: 400, code: "X", message: "m") }
      .to raise_error(described_class)
  end

  it "exposes to_h" do
    err = described_class.new(status: 404, code: "NOT_FOUND", message: "nope")
    expect(err.to_h[:status]).to eq(404)
    expect(err.to_h[:code]).to eq("NOT_FOUND")
  end
end
