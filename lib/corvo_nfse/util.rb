# frozen_string_literal: true

require "uri"

module CorvoNfse
  # Small shared helpers.
  module Util
    module_function

    # Percent-encode a single path segment (encodeURIComponent-equivalent).
    def enc(value)
      URI.encode_www_form_component(value.to_s).gsub("+", "%20")
    end

    # True for loopback / RFC1918 / link-local hosts (http:// allowed there).
    def private_host?(hostname)
      host = hostname.to_s.downcase.sub(/\.\z/, "")
      return true if ["localhost", "[::1]", "::1"].include?(host) || host.end_with?(".localhost")

      parts = host.split(".")
      return false unless parts.length == 4
      return false unless parts.all? { |p| p.match?(/\A\d+\z/) && p.to_i <= 255 }

      a = parts[0].to_i
      b = parts[1].to_i
      a == 127 || a == 10 || a == 0 ||
        (a == 192 && b == 168) ||
        (a == 172 && (16..31).cover?(b)) ||
        (a == 169 && b == 254)
    end
  end
end
