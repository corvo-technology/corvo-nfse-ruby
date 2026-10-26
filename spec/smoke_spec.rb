# frozen_string_literal: true

RSpec.describe "smoke" do
  it "loads the SDK and exposes the public surface" do
    expect(CorvoNfse::VERSION).to eq("0.2.0")
    expect(CorvoNfse::Client).to be_a(Class)
    expect(CorvoNfse::CorvoApiError).to be_a(Class)
    expect(CorvoNfse::Webhooks).to respond_to(:verify_signature)
    expect(CorvoNfse::Webhooks::SIGNATURE_PATTERN).to be_a(Regexp)
    expect(CorvoNfse::Types::Company.members).to include(:taxId, :taxRegime)
  end
end
