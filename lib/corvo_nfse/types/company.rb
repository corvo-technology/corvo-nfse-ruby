# frozen_string_literal: true

module CorvoNfse
  module Types
    # Adhesion of the company's municipality to the national NFS-e system.
    # +status+: not_checked, active, inactive, unknown or not_found.
    MunicipalityAgreement = define_data(:status, :agreementType, :checkedAt)

    # Numbering of the DPS (+GET/PUT /companies/{id}/dps-sequence+).
    DpsSequence = define_data(:series, :lastNumber)

    # One validity period of the fiscal profile of a company.
    FiscalProfile = define_data(
      :id, :tenantId, :companyId, :taxRegime, :simpleNational, :simplesApuracao,
      :simplesIssRate, :specialTaxRegime, :ibsCbsRegularOption,
      :ibsCbsRegularFrom, :reviewStatus, :reviewedAt, :reviewedBy, :source,
      :validFrom, :validUntil, :createdAt
    )

    # A service tax classification in the company catalog. +withholdingRates+
    # is a raw wire hash (irrf, pis, cofins, csll, inss).
    ServiceTaxProfile = define_data(
      :id, :tenantId, :companyId, :name, :serviceCode, :municipalServiceCode,
      :nbsCode, :classCode, :cst, :operationIndicator, :operationNature,
      :incidenceMunicipalityCode, :issTaxation, :issRate, :issWithholdingDefault,
      :withholdingPolicy, :withholdingRates, :regimeApplicability,
      :classificationSource, :catalogVersion, :reviewStatus, :effectiveFrom,
      :effectiveUntil, :createdAt
    )

    # A favorite service saved for a company.
    ServiceFavorite = define_data(
      :id, :tenantId, :companyId, :label, :description, :serviceCode,
      :municipalityCode, :amountCents, :createdAt
    )

    # Accountant e-mail of the monthly package (+GET+). +email+ nil means the
    # monthly send is off.
    AccountantSettings = define_data(:email, :lastSentMonth)

    # Answer of +PUT /companies/{companyId}/accountant-package+.
    AccountantSettingsUpdate = define_data(:email, :lastSentMonth, :testEmailSent)

    # One attempt to send the package. +status+: sent, skipped-empty,
    # skipped-too-large or failed; +trigger+: scheduled, manual or mcp-or-api.
    AccountantSend = define_data(
      :id, :month, :recipient, :status, :trigger, :invoiceCount, :totalCents,
      :createdAt
    )

    # Result of sending the package now. +status+: sent, skipped-test,
    # skipped-no-email, skipped-empty, skipped-too-large or
    # skipped-already-sent.
    AccountantSendResult = define_data(:status)

    # Count and total of a month package (+GET .../invoice-package/summary+).
    PackageSummary = define_data(
      :companyName, :companyTaxId, :month, :count, :total, :limit
    )
    # A fiscal company (the invoice issuer) registered with Corvo. Optional fields
    # are absent from the JSON when unset and read as nil. +setupGaps+ lists what is
    # still pending (municipality_code, certificate).
    Company = define_data(
      :id, :tenantId, :legalName, :tradeName, :taxId, :municipalReg,
      :sendMunicipalReg, :municipalityCode, :defaultServiceCode, :taxRegime, :simpleNational, :specialRegime,
      :simplesIssRate, :simplesRate,
      :addressStreet, :addressNumber, :addressComplement, :addressDistrict,
      :addressCity, :addressState, :addressZip, :fiscalSchemaVersion,
      :environment, :status, :createdAt, :updatedAt, :setupGaps,
      # What the Receita says about the municipality's adhesion to the national
      # system, and registry warnings (both nil when absent).
      :municipalityAgreement, :warnings
    ) do
      nested municipalityAgreement: MunicipalityAgreement
    end
  end
end
