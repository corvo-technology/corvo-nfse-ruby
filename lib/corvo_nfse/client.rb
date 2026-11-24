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
                :invoices, :plans, :webhooks, :base_url,
                :customers, :cnpj, :service_favorites, :accountant_package,
                :invoice_package, :schedules, :imports, :fiscal_profiles,
                :service_tax_profiles, :dps_sequence, :fiscal_portal,
                :integrations, :integration_connections, :integration_operations

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
      @plans = Resources::Plans.new(@transport)
      @webhooks = Resources::Webhooks.new(@transport)
      @customers = Resources::Customers.new(@transport)
      @cnpj = Resources::Cnpj.new(@transport)
      @service_favorites = Resources::ServiceFavorites.new(@transport)
      @accountant_package = Resources::AccountantPackage.new(@transport)
      @invoice_package = Resources::InvoicePackage.new(@transport)
      @schedules = Resources::Schedules.new(@transport)
      @imports = Resources::Imports.new(@transport)
      @fiscal_profiles = Resources::FiscalProfiles.new(@transport)
      @service_tax_profiles = Resources::ServiceTaxProfiles.new(@transport)
      @dps_sequence = Resources::DpsSequence.new(@transport)
      @fiscal_portal = Resources::FiscalPortal.new(@transport)
      @integrations = Resources::Integrations.new(@transport)
      @integration_connections = Resources::IntegrationConnections.new(@transport)
      @integration_operations = Resources::IntegrationOperations.new(@transport)
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
