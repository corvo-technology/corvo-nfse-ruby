# frozen_string_literal: true

module CorvoNfse
  module Resources
    # Import invoices from a CSV or Excel spreadsheet (snake_case fields).
    #
    #   job, error = client.imports.start(File.binread("notas.csv"), file_name: "notas.csv")
    #   # follow client.imports.get(job.id) until status is "ready", then:
    #   client.imports.emit(job.id)
    class Imports < Base
      JOB_MAPPER = ->(item) { Types::ImportJob.from_wire(item) }
      ROW_MAPPER = ->(item) { Types::ImportRow.from_wire(item) }

      CONTENT_TYPES = {
        ".csv" => "text/csv",
        ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      }.freeze

      # Upload a +.csv+ or +.xlsx+ (up to 2,000 rows and 10 MB). +file+ is the
      # file content (String of bytes) or an IO. Reading is asynchronous: follow
      # the import by id until it is +ready+. +company_id+ is the company that
      # issues the rows with no CNPJ column value.
      def start(file, file_name: "import.csv", content_type: nil, company_id: nil)
        content = file.respond_to?(:read) ? file.read : file
        type = content_type || CONTENT_TYPES.fetch(File.extname(file_name.to_s).downcase, "application/octet-stream")
        fields = [["file", content, type, file_name]]
        fields << ["companyId", company_id] if company_id
        @t.request_form("POST", "/imports", fields, type: Types::ImportStart)
      end

      # Recent imports (newest first, at most 20). Returns an Array.
      def list(limit: nil)
        data, error = @t.request("GET", "/imports", query: { limit: limit })
        return [nil, error] if error

        [Array(data).map { |item| JOB_MAPPER.call(item) }, nil]
      end

      def get(id)
        @t.request("GET", "/imports/#{Util.enc(id)}", type: Types::ImportJob)
      end

      # Emit every valid row. +send_email+ false skips the customer e-mail.
      def emit(id, send_email: nil)
        body = send_email.nil? ? nil : { sendEmail: send_email }
        @t.request("POST", "/imports/#{Util.enc(id)}/emit", json: body, type: Types::ImportJob)
      end

      # Rows of an import, one page at a time (default 50, at most 200).
      # +status+: valid, invalid, queued, accepted or rejected.
      def rows(id, status: nil, limit: nil, cursor: nil)
        @t.list_page(
          "/imports/#{Util.enc(id)}/rows",
          { status: status, limit: limit, cursor: cursor },
          mapper: ROW_MAPPER
        )
      end

      def iterate_rows(id, status: nil, limit: nil, cursor: nil, &block)
        @t.iterate(
          "/imports/#{Util.enc(id)}/rows",
          { status: status, limit: limit, cursor: cursor },
          mapper: ROW_MAPPER, &block
        )
      end

      # Correct one row and check it again (only while the import is ready).
      # +item+ holds the invoice fields to change (same shape as POST /invoices).
      def update_row(id, line, item)
        @t.request(
          "PATCH", "/imports/#{Util.enc(id)}/rows/#{Util.enc(line)}",
          json: { item: item }, type: Types::ImportRow
        )
      end

      # Discard an import that has not been emitted (204: no body).
      def discard(id)
        @t.request("DELETE", "/imports/#{Util.enc(id)}")
      end

      # The spreadsheet template, as a Types::DownloadedFile (CSV).
      def download_template
        @t.request_raw("GET", "/imports/template")
      end

      # CSV with the rows that need attention, as a Types::DownloadedFile.
      def download_errors(id)
        @t.request_raw("GET", "/imports/#{Util.enc(id)}/errors.csv")
      end
    end
  end
end
