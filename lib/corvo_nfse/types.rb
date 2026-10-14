# frozen_string_literal: true

module CorvoNfse
  # Immutable wire-faithful data types.
  #
  # Every type is a +Data+ class whose members mirror the API wire format
  # exactly (camelCase where the wire is camelCase, snake_case where the wire
  # is snake_case — e.g. the billing payloads). The SDK never re-cases server
  # fields: +from_wire+ maps the parsed JSON onto the type by key, and +to_wire+
  # maps it back verbatim.
  module Types
    # Class-side helpers mixed into every type.
    module ModelMethods
      # Build an instance from a parsed wire hash (string keys). Missing keys
      # default to +nil+; unknown extra keys are ignored so the type tolerates
      # server-side additions.
      def from_wire(hash)
        return nil if hash.nil?

        src = hash.is_a?(Hash) ? hash.transform_keys(&:to_sym) : {}
        vals = members.to_h { |m| [m, src[m]] }
        new(**vals)
      end
    end

    # Instance-side helpers mixed into every type.
    module InstanceMethods
      # Back to a wire-format hash (string keys), pass-through of values.
      def to_wire
        to_h.transform_keys(&:to_s)
      end
    end

    # Define an immutable wire type with the shared from_wire/to_wire helpers.
    def self.define_data(*members, &blk)
      Data.define(*members) do
        extend ModelMethods
        include InstanceMethods
        class_eval(&blk) if blk
      end
    end
  end
end

require_relative "types/common"
require_relative "types/company"
require_relative "types/invoice"
require_relative "types/certificate"
require_relative "types/webhook"
require_relative "types/credits"
require_relative "types/billing"
