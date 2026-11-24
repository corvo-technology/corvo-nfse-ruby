# frozen_string_literal: true

require "json"
require "uri"
require_relative "../support_operations"

# Contract coverage. spec/openapi.json is a vendored copy of the public API
# contract (docs/openapi/openapi.json in corvo-technology/corvo-nfse). Every
# operationId in it must be implemented by the SDK (OPERATIONS table), and each
# method must send the request the contract describes: HTTP method, path,
# query parameters, body fields and Idempotency-Key.
RSpec.describe "API contract coverage" do
  CONTRACT = JSON.parse(File.read(File.expand_path("../openapi.json", __dir__)))
  HTTP_METHODS = %w[get post put patch delete].freeze

  def self.contract_operations
    CONTRACT["paths"].flat_map do |path, item|
      item.select { |verb, _| HTTP_METHODS.include?(verb) }.map do |verb, op|
        { id: op["operationId"], verb: verb.upcase, path: path, op: op }
      end
    end
  end

  def deref(node)
    while node.is_a?(Hash) && node["$ref"]
      node = node["$ref"].delete_prefix("#/").split("/").reduce(CONTRACT) { |acc, key| acc.fetch(key) }
    end
    node
  end

  # Properties and required list of an object schema, following $ref/allOf.
  def object_shape(schema)
    schema = deref(schema)
    props = (schema["properties"] || {}).dup
    required = (schema["required"] || []).dup
    (schema["allOf"] || []).each do |part|
      sub_props, sub_required = object_shape(part)
      props.merge!(sub_props)
      required.concat(sub_required)
    end
    [props, required]
  end

  let(:client) { build_client }

  it "targets the contract version the SDK was written for" do
    expect(CONTRACT["info"]["version"]).to eq(CorvoNfse::API_CONTRACT_VERSION)
    expect(CONTRACT["servers"].first["url"]).to eq("https://api.corvo.tech/v1")
  end

  it "implements all operations of the contract and nothing else" do
    ids = self.class.contract_operations.map { |o| o[:id] }
    expect(ids.length).to eq(92)
    expect(OPERATIONS.keys.sort).to eq(ids.sort)
  end

  it "does not set an operationId twice" do
    ids = self.class.contract_operations.map { |o| o[:id] }
    expect(ids.uniq.length).to eq(ids.length)
  end

  contract_operations.each do |entry|
    it "#{entry[:id]} sends #{entry[:verb]} #{entry[:path]} as the contract says" do
      resource_path, method_name, args, kwargs = OPERATIONS.fetch(entry[:id])
      resource = resource_path.split(".").reduce(client) { |obj, name| obj.public_send(name) }

      stub = stub_request(:any, /localhost:4000/)
             .to_return(status: 200, body: { data: {}, pagination: { limit: 1, hasMore: false, nextCursor: nil } }.to_json,
                        headers: json_headers)
      _result, error = resource.public_send(method_name, *args, **kwargs)
      expect(error).to be_nil
      expect(stub).to have_been_requested.once

      captured = nil
      WebMock.after_request { |req, _res| captured = req }
      resource.public_send(method_name, *args, **kwargs)
      WebMock.reset_callbacks
      uri = URI.parse(captured.uri.to_s)

      # method + path (path parameters filled in order from the positional args)
      path_params = entry[:path].scan(/\{(\w+)\}/).flatten
      expected = entry[:path].dup
      path_params.each_with_index { |name, i| expected.sub!("{#{name}}", CorvoNfse::Util.enc(args[i])) }
      expect(captured.method.to_s.upcase).to eq(entry[:verb])
      expect(uri.path).to eq("/v1#{expected}")

      # headers
      expect(captured.headers["X-Api-Key"]).to eq(API_KEY)
      expect(captured.headers["User-Agent"]).to eq("corvo-nfse-ruby/#{CorvoNfse::VERSION}")
      declared = (entry[:op]["parameters"] || []).map { |p| deref(p) }
      if declared.any? { |p| p["in"] == "header" && p["name"] == "Idempotency-Key" }
        expect(captured.headers["Idempotency-Key"]).to eq("idem")
      else
        expect(captured.headers).not_to have_key("Idempotency-Key")
      end

      # query parameters: only declared ones, and the required ones present
      query = URI.decode_www_form(uri.query.to_s).to_h
      declared_query = declared.select { |p| p["in"] == "query" }
      expect(query.keys - declared_query.map { |p| p["name"] }).to eq([])
      declared_query.select { |p| p["required"] }.each { |p| expect(query).to have_key(p["name"]) }

      # request body: declared fields only, required ones present
      content = entry[:op].dig("requestBody", "content") || {}
      if content["application/json"]
        body = JSON.parse(captured.body)
        props, required = object_shape(content["application/json"]["schema"])
        if body.is_a?(Hash) && props.any?
          expect(body.keys - props.keys).to eq([])
          required.each { |name| expect(body).to have_key(name) }
        end
        expect(captured.headers["Content-Type"]).to start_with("application/json")
      elsif content["multipart/form-data"]
        expect(captured.headers["Content-Type"]).to start_with("multipart/form-data; boundary=")
        props, required = object_shape(content["multipart/form-data"]["schema"])
        names = captured.body.scan(/name="(\w+)"/).flatten
        expect(names - props.keys).to eq([])
        expect(required - names).to eq([])
      end
    end
  end
end
