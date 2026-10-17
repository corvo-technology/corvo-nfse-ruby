# frozen_string_literal: true

# Ruby SDK for the Corvo NFS-e API (https://corvo.tech).
#
# A small, stdlib-only client (net/http, uri, json, openssl, base64) exposing
# the full Corvo NFS-e surface with result-style ``[data, error]`` returns.
module CorvoNfse
end

require_relative "corvo_nfse/version"
require_relative "corvo_nfse/error"
require_relative "corvo_nfse/util"
require_relative "corvo_nfse/types"
require_relative "corvo_nfse/transport"
require_relative "corvo_nfse/webhooks"

require_relative "corvo_nfse/resources/base"
require_relative "corvo_nfse/resources/companies"
require_relative "corvo_nfse/resources/certificates"
require_relative "corvo_nfse/resources/invoices"
require_relative "corvo_nfse/resources/webhooks"
require_relative "corvo_nfse/resources/credits"
require_relative "corvo_nfse/resources/plans"
require_relative "corvo_nfse/resources/billing"
require_relative "corvo_nfse/resources/health"

require_relative "corvo_nfse/client"
