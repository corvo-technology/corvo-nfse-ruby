# frozen_string_literal: true

require "uri"

module CorvoNfse
  # Entry point for the Corvo NFS-e API.
  #
  #   client = CorvoNfse::Client.new(api_key: "corvo_live_xxx")  # or CORVO_API_KEY
  #   companies, error = client.companies.list(limit: 10)
  class Client
    DEFAULT_BASE_URL = "https://api.corvo.tech"
    ENV_API_KEY = "CORVO_API_KEY"
    ENV_BASE_URL = "CORVO_BASE_URL"

    attr_reader :billing, :certificates, :companies, :credits, :health,
                :invoices, :webhooks, :base_url

    def initialize(api_key: nil, base_url: nil, prefix: Transport::DEFAULT_PREFIX,
                   timeout: Transport::DEFAULT_TIMEOUT, allow_insecure_http: false)
      key = api_key || ENV[ENV_API_KEY]
      if key.nil? || key.empty?
        raise ArgumentError, "Corvo: api_key is required — pass api_key or set CORVO_API_KEY"
      end

      base = (base_url || ENV[ENV_BASE_URL] || DEFAULT_BASE_URL).to_s.sub(%r{/+\z}, "")
      uri = parse_base(base)

      if uri.scheme == "http" && !allow_insecure_http && !Util.private_host?(uri.host)
        raise ArgumentError,
              "Corvo: http:// is only allowed for loopback/private hosts " \
              "(got #{uri.host}). Use https:// or pass allow_insecure_http: true."
      end

      @transport = Transport.new(api_key: key, base_url: base, prefix: prefix, timeout: timeout)
      @base_url = @transport.base_url
      @billing = Resources::Billing.new(@transport)
      @certificates = Resources::Certificates.new(@transport)
      @companies = Resources::Companies.new(@transport)
      @credits = Resources::Credits.new(@transport)
      @health = Resources::Health.new(@transport)
      @invoices = Resources::Invoices.new(@transport)
      @webhooks = Resources::Webhooks.new(@transport)
    end

    private

    def parse_base(base)
      uri = URI.parse(base)
      unless uri.is_a?(URI::HTTP) && uri.host
        raise ArgumentError, "Corvo: invalid base_url: #{base}"
      end

      uri
    rescue URI::InvalidURIError
      raise ArgumentError, "Corvo: invalid base_url: #{base}"
    end
  end
end
