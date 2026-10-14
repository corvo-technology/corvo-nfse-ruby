# frozen_string_literal: true

require "openssl"

module CorvoNfse
  # Helpers for consuming Corvo webhooks.
  module Webhooks
    SIGNATURE_PATTERN = /\Asha256=([0-9a-f]{64})\z/

    module_function

    # Verify an ``X-Corbo-Signature: sha256=<hex>`` header (HMAC-SHA256).
    #
    # Pass the raw request bytes — re-serialized JSON will not match the HMAC.
    # Comparison is constant-time via +OpenSSL.fixed_length_secure_compare+.
    #
    #   raw = request.body.read
    #   CorvoNfse::Webhooks.verify_signature(raw, headers["X-Corbo-Signature"], secret)
    def verify_signature(raw_body, signature_header, secret)
      return false unless signature_header.is_a?(String) && secret.is_a?(String) && !secret.empty?

      match = SIGNATURE_PATTERN.match(signature_header.strip)
      return false unless match

      body = raw_body.is_a?(String) ? raw_body : raw_body.to_s
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, body)
      constant_time_equals(match[1], expected)
    end

    def constant_time_equals(a, b)
      return false unless a.bytesize == b.bytesize

      OpenSSL.fixed_length_secure_compare(a, b)
    end
  end
end
