# frozen_string_literal: true

module CorvoNfse
  # Typed error carrying the server's stable ``code`` and HTTP context.
  #
  # It is both the value inside a ``[nil, error]`` result AND a raiseable
  # exception. API, network, and timeout failures are returned as values, not
  # raised. The single documented exception is the ``iterate`` helpers, which
  # raise the error on first-page failure because a block/enumerator has no
  # return slot for it.
  #
  # Network and timeout failures use ``status = 0`` and a ``code`` of
  # ``"network_error"`` or ``"timeout"``.
  class CorvoApiError < StandardError
    attr_reader :status, :code, :details, :request_id, :retry_after

    def initialize(status:, code:, message:, details: nil, request_id: nil, retry_after: nil)
      super(message)
      @status = status
      @code = code
      @details = details || []
      @request_id = request_id
      @retry_after = retry_after
    end

    def to_h
      {
        status: status,
        code: code,
        message: message,
        details: details,
        request_id: request_id,
        retry_after: retry_after
      }
    end
  end
end
