# frozen_string_literal: true

module CorvoNfse
  module Types
    # A customer saved by a previous invoice (+/customers+). +email+ is nil when
    # none is known.
    SavedCustomer = define_data(:taxId, :name, :email, :lastUsedAt, :createdAt, :updatedAt)

    # Address in the registry data of a CNPJ.
    PostalAddress = define_data(
      :street, :number, :complement, :district, :city, :state, :zip
    )

    # Registration data of a CNPJ (+GET /cnpj/{cnpj}+). +mei+, +simples+ and
    # +municipalityCode+ are nil when the registry does not say.
    CnpjProfile = define_data(
      :legalName, :tradeName, :active, :situation, :mei, :simples,
      :municipalityCode, :address
    ) do
      nested address: PostalAddress
    end
  end
end
