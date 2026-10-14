# frozen_string_literal: true

module CorvoNfse
  module Types
    # A stored A1/A3 signing certificate (PKCS#12) for a company.
    Certificate = define_data(
      :id, :companyId, :serialNumber, :issuer, :subject, :fingerprint,
      :validFrom, :validUntil, :status, :createdAt
    )
  end
end
