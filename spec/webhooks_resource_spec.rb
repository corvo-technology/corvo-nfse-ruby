# frozen_string_literal: true

RSpec.describe "webhooks resource" do
  let(:client) { build_client }

  it "create returns the secret once; list/remove/test behave" do
    wh = { id: "wh_1", url: "https://x.test", events: ["webhook.test"], active: true, secret: "whsec_1" }
    stub_request(:post, "#{BASE_URL}/v1/webhooks")
      .to_return(status: 201, body: { data: wh }.to_json, headers: json_headers)
    stub_request(:get, "#{BASE_URL}/v1/webhooks")
      .to_return(status: 200, body: { data: [wh], pagination: { limit: 10, hasMore: false, nextCursor: nil } }.to_json, headers: json_headers)
    stub_request(:delete, "#{BASE_URL}/v1/webhooks/wh_1").to_return(status: 200, body: { data: { deleted: true } }.to_json, headers: json_headers)
    stub_request(:post, "#{BASE_URL}/v1/webhooks/wh_1/test").to_return(status: 200, body: { data: { sent: true } }.to_json, headers: json_headers)

    created, cerr = client.webhooks.create(url: "https://x.test", events: ["webhook.test"])
    expect(cerr).to be_nil
    expect(created).to be_a(CorvoNfse::Types::WebhookWithSecret)
    expect(created.secret).to eq("whsec_1")

    page, lerr = client.webhooks.list
    expect(lerr).to be_nil
    expect(page.data.first).to be_a(CorvoNfse::Types::Webhook)

    deleted, derr = client.webhooks.remove("wh_1")
    expect(derr).to be_nil
    expect(deleted).to eq({ "deleted" => true })

    sent, serr = client.webhooks.test("wh_1")
    expect(serr).to be_nil
    expect(sent).to eq({ "sent" => true })
  end

  it "deliveries list/iterate/stats/retry work" do
    stub_request(:get, "#{BASE_URL}/v1/webhooks/deliveries")
      .with(query: { "hours" => "24" })
      .to_return(
        status: 200,
        body: { data: [{ id: "dl_1", eventType: "webhook.test" }], pagination: { limit: 10, hasMore: false, nextCursor: nil } }.to_json,
        headers: json_headers
      )
    stub_request(:get, "#{BASE_URL}/v1/webhooks/deliveries/stats")
      .with(query: { "hours" => "24" })
      .to_return(status: 200, body: { data: { total: 1, sent: 1, failed: 0, pending: 0, delayed: 0 } }.to_json, headers: json_headers)
    stub_request(:post, "#{BASE_URL}/v1/webhooks/deliveries/dl_1/retry")
      .to_return(status: 200, body: { data: { retried: true } }.to_json, headers: json_headers)

    page, error = client.webhooks.deliveries.list(hours: 24)
    expect(error).to be_nil
    expect(page.data.first).to be_a(CorvoNfse::Types::WebhookDelivery)

    stats, serr = client.webhooks.deliveries.stats(hours: 24)
    expect(serr).to be_nil
    expect(stats.total).to eq(1)

    retried, rerr = client.webhooks.deliveries.retry("dl_1")
    expect(rerr).to be_nil
    expect(retried).to eq({ "retried" => true })
  end
end
