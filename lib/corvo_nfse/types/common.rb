# frozen_string_literal: true

module CorvoNfse
  module Types
    # Pagination cursor metadata returned by every list endpoint.
    Pagination = define_data(:limit, :hasMore, :nextCursor)

    # A single list page: +data+ items plus +pagination+ metadata.
    Paginated = define_data(:data, :pagination)

    # Binary payload from ``/invoices/:id/pdf|xml``. This one is SDK-side (not a
    # wire envelope), hence the snake_case members.
    DownloadedFile = define_data(:content, :mime_type, :file_name)
  end
end
