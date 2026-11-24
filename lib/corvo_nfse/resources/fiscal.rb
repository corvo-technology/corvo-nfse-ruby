# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Fiscal profile history of a company (tax regime, validity periods).
    class FiscalProfiles < Base
      MAPPER = ->(item) { Types::FiscalProfile.from_wire(item) }

      # Returns an Array of profiles (the history).
      def list(company_id)
        data, error = @t.request("GET", base(company_id))
        return [nil, error] if error

        [Array(data).map { |item| MAPPER.call(item) }, nil]
      end

      # Create a validity period (idempotent for an identical desired state).
      # +params+: taxRegime (required), simpleNational, simplesApuracao,
      # specialTaxRegime, ibsCbsRegularOption, ibsCbsRegularFrom, validFrom, confirm.
      def upsert(company_id, **params)
        @t.request("PUT", base(company_id), json: params, type: Types::FiscalProfile)
      end

      def approve(company_id, profile_id)
        @t.request(
          "POST", "#{base(company_id)}/#{Util.enc(profile_id)}/approve",
          type: Types::FiscalProfile
        )
      end

      private

      def base(company_id)
        "/companies/#{Util.enc(company_id)}/fiscal-profile"
      end
    end

    # Service tax classifications in the catalog of a company.
    class ServiceTaxProfiles < Base
      MAPPER = ->(item) { Types::ServiceTaxProfile.from_wire(item) }

      # Profiles effective on +date+ (YYYY-MM-DD, default today). Returns an Array.
      def list(company_id, date: nil)
        data, error = @t.request("GET", base(company_id), query: { date: date })
        return [nil, error] if error

        [Array(data).map { |item| MAPPER.call(item) }, nil]
      end

      # +params+: name, serviceCode, effectiveFrom (required) and the optional
      # classification fields.
      def create(company_id, **params)
        @t.request("POST", base(company_id), json: params, type: Types::ServiceTaxProfile)
      end

      def update(company_id, service_id, **params)
        @t.request(
          "PATCH", "#{base(company_id)}/#{Util.enc(service_id)}",
          json: params, type: Types::ServiceTaxProfile
        )
      end

      # Delete an expired, not yet approved profile.
      def remove(company_id, service_id)
        @t.request("DELETE", "#{base(company_id)}/#{Util.enc(service_id)}")
      end

      def approve(company_id, service_id)
        @t.request(
          "POST", "#{base(company_id)}/#{Util.enc(service_id)}/approve",
          type: Types::ServiceTaxProfile
        )
      end

      private

      def base(company_id)
        "/companies/#{Util.enc(company_id)}/service-tax-profiles"
      end
    end

    # DPS numbering of a company.
    class DpsSequence < Base
      def get(company_id)
        @t.request("GET", path(company_id), type: Types::DpsSequence)
      end

      # Continue the numbering from the last note issued in another system.
      # +last_number+ below the current one answers +DPS_NUMBER_BELOW_CURRENT+.
      def set(company_id, last_number:)
        @t.request(
          "PUT", path(company_id),
          json: { lastNumber: last_number }, type: Types::DpsSequence
        )
      end

      private

      def path(company_id)
        "/companies/#{Util.enc(company_id)}/dps-sequence"
      end
    end

    # Whether the national NFS-e portal is answering.
    class FiscalPortal < Base
      def status
        @t.request("GET", "/fiscal-portal/status", type: Types::PortalStatus)
      end
    end
  end
end
