# frozen_string_literal: true

require_relative "lib/corvo_nfse/version"

Gem::Specification.new do |spec|
  spec.name = "corvo-nfse"
  spec.version = CorvoNfse::VERSION
  spec.authors = ["Corvo Technology"]
  spec.email = ["support@corvo.tech"]

  spec.summary = "Ruby SDK for the Corvo NFS-e API: issue Brazilian service invoices."
  spec.description = "A stdlib-only (net/http) Ruby client for the Corvo NFS-e " \
                     "electronic invoicing API: companies, certificates, invoices, " \
                     "webhooks, credits and billing, with result-style [data, error] " \
                     "returns and HMAC webhook verification."
  spec.homepage = "https://corvo.tech"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2" # Data.define requires Ruby 3.2+

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/corvo-technology/corvo-nfse-ruby"
  spec.metadata["documentation_uri"] = "https://corvo.tech/en/docs"
  spec.metadata["bug_tracker_uri"] = "https://github.com/corvo-technology/corvo-nfse-ruby/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb"] + %w[LICENSE README.md]
  spec.require_paths = ["lib"]

  # Runtime dependencies: none (stdlib only).
  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
end
