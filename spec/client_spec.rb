# frozen_string_literal: true

RSpec.describe CorvoNfse::Client do
  it "requires an api key" do
    expect { described_class.new(api_key: nil, base_url: BASE_URL) }
      .to raise_error(ArgumentError, /api_key is required/)
  end

  it "exposes every resource namespace" do
    client = build_client
    %i[billing certificates companies credits health invoices webhooks].each do |name|
      expect(client.public_send(name)).not_to be_nil
    end
    expect(client.webhooks.deliveries).not_to be_nil
  end

  it "rejects a non-loopback http:// base without allow_insecure_http" do
    expect { described_class.new(api_key: API_KEY, base_url: "http://api.example.com") }
      .to raise_error(ArgumentError, %r{http://})
  end

  it "rejects an invalid base_url" do
    expect { described_class.new(api_key: API_KEY, base_url: "not a url") }
      .to raise_error(ArgumentError, /invalid base_url/)
  end

  it "allows loopback http:// without allow_insecure_http" do
    expect { described_class.new(api_key: API_KEY, base_url: BASE_URL) }.not_to raise_error
  end

  it "reads the api key from CORVO_API_KEY" do
    begin
      ENV["CORVO_API_KEY"] = API_KEY
      client = described_class.new(base_url: BASE_URL)
      expect(client.companies).not_to be_nil
    ensure
      ENV.delete("CORVO_API_KEY")
    end
  end
end
