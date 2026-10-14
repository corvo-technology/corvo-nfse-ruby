# frozen_string_literal: true

require "corvo_nfse"
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: false)

API_KEY = "corvo_test_#{'a' * 40}"
BASE_URL = "http://localhost:4000"

module SpecHelpers
  def json_headers(extra = {})
    { "Content-Type" => "application/json" }.merge(extra)
  end

  def build_client(**opts)
    CorvoNfse::Client.new({ api_key: API_KEY, base_url: BASE_URL }.merge(opts))
  end
end

RSpec.configure do |config|
  config.include SpecHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
