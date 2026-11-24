# frozen_string_literal: true

module CorvoNfse
  module Resources
    # The monthly package (XML, PDF and a CSV summary) sent to the accountant.
    class AccountantPackage < Base
      SEND_MAPPER = ->(item) { Types::AccountantSend.from_wire(item) }

      def get(company_id)
        @t.request("GET", base(company_id), type: Types::AccountantSettings)
      end

      # Set the accountant e-mail. +nil+ turns the monthly send off.
      def update(company_id, accountant_email)
        @t.request(
          "PUT", base(company_id),
          json: { accountantEmail: accountant_email },
          type: Types::AccountantSettingsUpdate
        )
      end

      # Send the package of +month+ ("YYYY-MM") to the accountant now.
      def send_package(company_id, month:)
        @t.request(
          "POST", "#{base(company_id)}/send",
          json: { month: month },
          type: Types::AccountantSendResult
        )
      end

      # Last 12 attempts to send the package. Returns an Array.
      def list_sends(company_id)
        data, error = @t.request("GET", "#{base(company_id)}/sends")
        return [nil, error] if error

        [Array(data).map { |item| SEND_MAPPER.call(item) }, nil]
      end

      private

      def base(company_id)
        "/companies/#{Util.enc(company_id)}/accountant-package"
      end
    end

    # Month package of invoices (ZIP with xml/, pdf/ and resumo.csv).
    class InvoicePackage < Base
      # Count and total of the month, without building the ZIP.
      def summary(company_id, month:)
        @t.request(
          "GET", "/companies/#{Util.enc(company_id)}/invoice-package/summary",
          query: { month: month }, type: Types::PackageSummary
        )
      end

      # Download the ZIP as a Types::DownloadedFile. +include+ is "xml", "pdf"
      # or "xml,pdf" (default: both).
      def download(company_id, month:, include: nil)
        @t.request_raw(
          "GET", "/companies/#{Util.enc(company_id)}/invoice-package",
          query: { month: month, include: include }
        )
      end
    end
  end
end
