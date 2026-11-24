# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Customers saved by earlier invoices: search, iterate, get, update, remove.
    # +tax_id+ is a CPF or CNPJ (digits).
    class Customers < Base
      MAPPER = ->(item) { Types::SavedCustomer.from_wire(item) }

      # List saved customers, most recently used first. +search+ is part of the
      # name or the first digits of the CPF/CNPJ. The +nextCursor+ of this list
      # is the offset of the next page: pass it back untouched.
      def search(search: nil, limit: nil, cursor: nil)
        @t.list_page("/customers", { search: search, limit: limit, cursor: cursor }, mapper: MAPPER)
      end

      def iterate(search: nil, limit: nil, cursor: nil, &block)
        @t.iterate("/customers", { search: search, limit: limit, cursor: cursor }, mapper: MAPPER, &block)
      end

      def get(tax_id)
        @t.request("GET", "/customers/#{Util.enc(tax_id)}", type: Types::SavedCustomer)
      end

      # Correct the +name+ or the +email+ (nil clears it) of a saved customer.
      def update(tax_id, **params)
        @t.request("PATCH", "/customers/#{Util.enc(tax_id)}", json: params, type: Types::SavedCustomer)
      end

      # Forget a saved customer; issued invoices are not changed. Returns the
      # raw +{"deleted" => true}+ hash... or nil when the API answers no body.
      def remove(tax_id)
        @t.request("DELETE", "/customers/#{Util.enc(tax_id)}")
      end
    end

    # CNPJ registry lookup.
    class Cnpj < Base
      # Registration data of a CNPJ (digits or formatted). Errors such as
      # +CNPJ_INVALID+ and +CNPJ_LOOKUP_UNAVAILABLE+ come back as the error.
      def lookup(cnpj)
        @t.request("GET", "/cnpj/#{Util.enc(cnpj)}", type: Types::CnpjProfile)
      end
    end

    # Favorite services of a company.
    class ServiceFavorites < Base
      MAPPER = ->(item) { Types::ServiceFavorite.from_wire(item) }

      # All favorites of the company (a plain list, not paginated). Returns an Array.
      def list(company_id)
        data, error = @t.request("GET", "/companies/#{Util.enc(company_id)}/service-favorites")
        return [nil, error] if error

        [Array(data).map { |item| MAPPER.call(item) }, nil]
      end

      # +params+: label, description, serviceCode, municipalityCode, amountCents.
      def create(company_id, **params)
        @t.request(
          "POST", "/companies/#{Util.enc(company_id)}/service-favorites",
          json: params, type: Types::ServiceFavorite
        )
      end

      # Returns the raw +{"deleted" => true}+ hash.
      def remove(company_id, favorite_id)
        @t.request(
          "DELETE",
          "/companies/#{Util.enc(company_id)}/service-favorites/#{Util.enc(favorite_id)}"
        )
      end
    end
  end
end
