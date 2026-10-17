# frozen_string_literal: true

module CorvoNfse
  module Types
    # A fiscal company (the invoice issuer) registered with Corvo. Optional fields
    # are absent from the JSON when unset and read as nil. +setupGaps+ lists what is
    # still pending (municipality_code, certificate).
    Company = define_data(
      :id, :tenantId, :legalName, :tradeName, :taxId, :municipalReg,
      :sendMunicipalReg, :municipalityCode, :defaultServiceCode, :taxRegime, :simpleNational, :specialRegime,
      :addressStreet, :addressNumber, :addressComplement, :addressDistrict,
      :addressCity, :addressState, :addressZip, :fiscalSchemaVersion,
      :environment, :status, :createdAt, :updatedAt, :deletedAt, :setupGaps
    )
  end
end
