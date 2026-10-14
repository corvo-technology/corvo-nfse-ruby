# frozen_string_literal: true

RSpec.describe CorvoNfse::Webhooks do
  BODY = '{"type":"nfse.invoice.authorized","data":{"id":"inv_1"}}'
  SECRET = "whsec_test_123"
  SIGNATURE = "sha256=8f9bd040d8f717b19618ab3395ddfa4b8c176b8dc863195227b88dd85426bbbc"

  it "accepts the known HMAC-SHA256 vector" do
    expect(described_class.verify_signature(BODY, SIGNATURE, SECRET)).to be true
  end

  it "rejects a tampered body" do
    tampered = BODY.sub("inv_1", "inv_2")
    expect(described_class.verify_signature(tampered, SIGNATURE, SECRET)).to be false
  end

  it "rejects a wrong secret" do
    expect(described_class.verify_signature(BODY, SIGNATURE, "whsec_other")).to be false
  end

  it "rejects malformed or missing headers" do
    expect(described_class.verify_signature(BODY, nil, SECRET)).to be false
    expect(described_class.verify_signature(BODY, "", SECRET)).to be false
    expect(described_class.verify_signature(BODY, SIGNATURE.sub("sha256=", ""), SECRET)).to be false
    expect(described_class.verify_signature(BODY, "sha256=zzzz", SECRET)).to be false
    expect(described_class.verify_signature(BODY, SIGNATURE, "")).to be false
  end
end
