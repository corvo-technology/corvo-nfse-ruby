# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Companies — create, get, update, remove, list, iterate.
    class Companies < Base
      def create(**params)
        @t.request("POST", "/companies", json: params, type: Types::Company)
      end

      def list(limit: nil, cursor: nil)
        @t.list_page(
          "/companies",
          { limit: limit, cursor: cursor },
          mapper: ->(item) { Types::Company.from_wire(item) }
        )
      end

      def iterate(limit: nil, cursor: nil, &block)
        @t.iterate(
          "/companies",
          { limit: limit, cursor: cursor },
          mapper: ->(item) { Types::Company.from_wire(item) },
          &block
        )
      end

      def get(id)
        @t.request("GET", "/companies/#{Util.enc(id)}", type: Types::Company)
      end

      # The CNPJ (+taxId+) cannot be changed, so it is not sent.
      def update(id, **params)
        params = params.reject { |key, _| key.to_s == "taxId" }
        @t.request("PATCH", "/companies/#{Util.enc(id)}", json: params, type: Types::Company)
      end

      def remove(id)
        @t.request("DELETE", "/companies/#{Util.enc(id)}")
      end
    end
  end
end
