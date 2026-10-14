# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Certificates — upload (multipart), list, remove.
    class Certificates < Base
      # Upload a PKCS#12 certificate (max 50 KiB). The SDK builds the form.
      def upload(company_id, file, password, file_name: "certificate.p12")
        fields = [
          ["file", file, "application/x-pkcs12", file_name],
          ["password", password]
        ]
        @t.request_form(
          "POST",
          "/companies/#{Util.enc(company_id)}/certificates",
          fields,
          type: Types::Certificate
        )
      end

      def list(company_id, limit: nil, cursor: nil)
        @t.list_page(
          "/companies/#{Util.enc(company_id)}/certificates",
          { limit: limit, cursor: cursor },
          mapper: ->(item) { Types::Certificate.from_wire(item) }
        )
      end

      def remove(company_id, certificate_id)
        @t.request(
          "DELETE",
          "/companies/#{Util.enc(company_id)}/certificates/#{Util.enc(certificate_id)}"
        )
      end
    end
  end
end
