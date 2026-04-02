# frozen_string_literal: true

require_relative "int_to_uuid/version"
require_relative "int_to_uuid/integer_id"
require_relative "int_to_uuid/encoder"

module IntToUuid
  VALIDATION_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  def self.encode(value_or_id, namespace: 0)
    Encoder.encode(value_or_id, namespace: namespace)
  end

  def self.decode(uuid_string)
    Encoder.decode(uuid_string)
  end
end
