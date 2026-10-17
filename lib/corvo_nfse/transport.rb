# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "openssl"

module CorvoNfse
  # Thin synchronous HTTP layer over +Net::HTTP+ (keep-alive).
  #
  # Every resource routes through here. It never raises for API, network, or
  # timeout failures — those come back as ``[nil, error]``. Two envelope helpers
  # live here: ``unwrap`` (modes ``data`` / ``none``) and
  # ``to_error`` (non-2xx -> CorvoApiError).
  class Transport
    DEFAULT_PREFIX = "v1"
    DEFAULT_TIMEOUT = 30

    attr_reader :base_url

    def initialize(api_key:, base_url:, prefix: DEFAULT_PREFIX, timeout: DEFAULT_TIMEOUT)
      @api_key = api_key
      root = base_url.to_s.sub(%r{/+\z}, "")
      cleaned = (prefix || "").to_s.gsub(%r{\A/+|/+\z}, "")
      @base_url = cleaned.empty? ? root : "#{root}/#{cleaned}"
      @timeout = timeout

      root_uri = URI.parse(root)
      @http = Net::HTTP.new(root_uri.host, root_uri.port)
      @http.use_ssl = root_uri.scheme == "https"
      @http.open_timeout = timeout
      @http.read_timeout = timeout
      @http.write_timeout = timeout if @http.respond_to?(:write_timeout=)
    end

    # Returns ``[data, error]``. +type+ is an optional Types:: data class the
    # unwrapped payload is mapped onto.
    def request(method, path, json: nil, query: nil, idempotency_key: nil, unwrap: "data", type: nil)
      uri = build_uri(path, query)
      req = request_class(method).new(uri)
      apply_headers(req, idempotency_key)
      if json
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(json)
      end
      res, error = perform(req)
      return [nil, error] if error

      data, herror = handle_response(res, unwrap)
      return [nil, herror] if herror

      [map_type(data, type), nil]
    end

    # Multipart upload. The SDK passes +fields+ to +set_form+, which sets the
    # ``multipart/form-data`` Content-Type (with boundary) itself — we never set
    # it manually.
    def request_form(method, path, fields, unwrap: "data", type: nil)
      uri = build_uri(path, nil)
      req = request_class(method).new(uri)
      apply_headers(req, nil)
      boundary = "----CorvoFormBoundary#{rand(0x100000000).to_s(16)}"
      req.body = encode_multipart(fields, boundary)
      req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      res, error = perform(req)
      return [nil, error] if error

      data, herror = handle_response(res, unwrap)
      return [nil, herror] if herror

      [map_type(data, type), nil]
    end

    # RFC 7578 multipart body: a `file` part (with filename + content type) and
    # plain text parts, matching the canonical Node SDK's wire shape.
    def encode_multipart(fields, boundary)
      body = +""
      fields.each do |field|
        body << "--#{boundary}\r\n"
        if field.length == 4
          name, content, content_type, filename = field
          body << %(Content-Disposition: form-data; name="#{name}"; filename="#{filename}"\r\n)
          body << "Content-Type: #{content_type}\r\n\r\n"
          body << content.to_s
          body << "\r\n"
        else
          name, content = field
          body << %(Content-Disposition: form-data; name="#{name}"\r\n\r\n)
          body << content.to_s
          body << "\r\n"
        end
      end
      body << "--#{boundary}--\r\n"
      body
    end

    # Binary download: returns a Types::DownloadedFile.
    def request_raw(method, path, query: nil)
      uri = build_uri(path, query)
      req = request_class(method).new(uri)
      apply_headers(req, nil)
      res, error = perform(req)
      return [nil, error] if error

      status = res.code.to_i
      return [nil, nil] if status == 204
      return [nil, to_error(res)] unless (200..299).cover?(status)

      disposition = res["Content-Disposition"]
      file_name = disposition && disposition[/filename="([^"]+)"/, 1]
      [
        Types::DownloadedFile.new(
          content: res.body.to_s.b,
          mime_type: res["Content-Type"],
          file_name: file_name
        ),
        nil
      ]
    end

    # One list page as a Types::Paginated (``{ data, pagination }``).
    def list_page(path, query = nil, mapper: nil)
      raw, error = request("GET", path, query: query, unwrap: "none")
      return [nil, error] if error

      body = raw.is_a?(Hash) ? raw : {}
      items = body["data"]
      items = items.is_a?(Array) ? items : []
      items = items.map { |item| mapper.call(item) } if mapper
      pagination = body["pagination"]
      pag = pagination.is_a?(Hash) ? Types::Pagination.from_wire(pagination) : nil
      [Types::Paginated.new(data: items, pagination: pag), nil]
    end

    # Walk cursor pages, yielding every item. Without a block returns an
    # Enumerator.
    #
    # The one place in the SDK that raises: a first-page (or any-page) failure
    # raises CorvoApiError instead of returning a tuple, because an
    # Enumerator/block has no result slot for it.
    def iterate(path, query = nil, mapper: nil)
      unless block_given?
        return Enumerator.new do |yielder|
          iterate(path, query, mapper: mapper) { |item| yielder << item }
        end
      end

      base_query = (query || {}).dup
      cursor = base_query[:cursor]
      loop do
        page_query = base_query.merge(cursor: cursor)
        page, error = list_page(path, page_query, mapper: mapper)
        raise error if error

        page.data.each { |item| yield item }
        pag = page.pagination
        return unless pag && pag.hasMore

        cursor = pag.nextCursor
        return if cursor.nil?
      end
    end

    # Map a non-2xx response to a typed error (see shared spec).
    def to_error(res)
      status = res.code.to_i
      body = {}
      if res["Content-Type"].to_s.start_with?("application/json")
        begin
          parsed = JSON.parse(res.body.to_s)
          body = parsed if parsed.is_a?(Hash)
        rescue JSON::ParserError
          body = {}
        end
      end

      code = body["code"].is_a?(String) && !body["code"].empty? ? body["code"] : "http_#{status}"
      raw_message = body["message"]
      message =
        if raw_message.is_a?(String)
          raw_message
        elsif raw_message.is_a?(Array)
          raw_message.map(&:to_s).join("; ")
        elsif body["error"].is_a?(String)
          body["error"]
        else
          "Request failed with status #{status}"
        end
      details = body["details"].is_a?(Array) ? body["details"] : []
      request_id = body["requestId"] || res["X-Request-Id"]

      retry_after = body["retryAfter"]
      if retry_after.is_a?(Numeric)
        retry_after = retry_after.to_i
      else
        header = res["Retry-After"]
        retry_after = header && header.match?(/\A-?\d+\z/) ? header.to_i : nil
      end

      CorvoApiError.new(
        status: status,
        code: code,
        message: message,
        details: details,
        request_id: request_id,
        retry_after: retry_after
      )
    end

    private

    def build_uri(path, query)
      uri = URI.parse("#{@base_url}#{path}")
      params = (query || {}).compact
      uri.query = URI.encode_www_form(params) unless params.empty?
      uri
    end

    def request_class(method)
      case method.to_s.upcase
      when "GET" then Net::HTTP::Get
      when "POST" then Net::HTTP::Post
      when "PATCH" then Net::HTTP::Patch
      when "PUT" then Net::HTTP::Put
      when "DELETE" then Net::HTTP::Delete
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end

    def apply_headers(req, idempotency_key)
      req["X-API-Key"] = @api_key
      req["Accept"] = "application/json"
      req["Idempotency-Key"] = idempotency_key if idempotency_key
    end

    def handle_response(res, unwrap_mode)
      status = res.code.to_i
      return [nil, nil] if status == 204
      return [nil, to_error(res)] unless (200..299).cover?(status)

      body = res.body.to_s
      return [nil, nil] if body.empty?

      begin
        parsed = JSON.parse(body)
      rescue JSON::ParserError
        return [nil, invalid_json_error(status, res)]
      end
      [unwrap(parsed, unwrap_mode), nil]
    end

    def invalid_json_error(status, res)
      CorvoApiError.new(
        status: status,
        code: "invalid_json",
        message: "Invalid JSON in response",
        details: [],
        request_id: res["X-Request-Id"]
      )
    end

    def unwrap(value, mode)
      return value if mode == "none"

      value.is_a?(Hash) ? value["data"] : nil
    end

    def map_type(data, type)
      return data unless type

      data.nil? ? nil : type.from_wire(data)
    end

    def perform(req)
      [@http.request(req), nil]
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
      [nil, timeout_error(e)]
    rescue SocketError, EOFError, IOError, OpenSSL::SSL::SSLError,
           Net::HTTPBadResponse, SystemCallError => e
      [nil, network_error(e)]
    end

    def timeout_error(e)
      CorvoApiError.new(
        status: 0,
        code: "timeout",
        message: "Request timed out after #{@timeout}s: #{e}",
        details: []
      )
    end

    def network_error(e)
      CorvoApiError.new(
        status: 0,
        code: "network_error",
        message: "Network request failed: #{e}",
        details: []
      )
    end
  end
end
