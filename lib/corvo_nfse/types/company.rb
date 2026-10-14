# frozen_string_literal: true

module CorvoNfse
  module Types
    # A fiscal company (tomador/prestador) registered with Corvo.
    Company = define_data(
      :id, :tenantId, :legalName, :tradeName, :taxId, :municipalReg,
      :municipalityCode, :taxRegime, :simpleNational, :specialRegime,
      :addressStreet, :addressNumber, :addressComplement, :addressDistrict,
      :addressCity, :addressState, :addressZip, :fiscalSchemaVersion,
      :environment, :status, :createdAt, :updatedAt, :deletedAt, :setupGaps
    )
  end
end
