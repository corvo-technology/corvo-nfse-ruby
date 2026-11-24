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
        nested_types.each do |name, type|
          value = vals[name]
          vals[name] =
            if value.is_a?(Array)
              value.map { |item| item.is_a?(Hash) ? type.from_wire(item) : item }
            elsif value.is_a?(Hash)
              type.from_wire(value)
            else
              value
            end
        end
        new(**vals)
      end

      # Members whose value is itself a typed object (or an array of them).
      # Call with a +{ member => Type }+ hash to declare, without arguments to
      # read. Members not declared here stay raw wire hashes.
      def nested(map = nil)
        @nested_types = map if map
        @nested_types || {}
      end

      def nested_types
        nested
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
require_relative "types/customer"
require_relative "types/schedule"
require_relative "types/import"
require_relative "types/integration"
