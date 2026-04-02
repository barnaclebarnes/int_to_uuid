# frozen_string_literal: true

require "digest/xxhash"

module IntToUuid
  module Encoder
    module_function

    def encode(value_or_id, namespace: 0)
      if value_or_id.is_a?(IntegerId)
        id_obj = value_or_id
      else
        id_obj = IntegerId.new(value_or_id, namespace: namespace)
      end

      packed_id = [id_obj.value].pack("Q>")
      packed_namespace = [id_obj.namespace].pack("N")

      s = compute_seed(packed_id, packed_namespace)
      encoded_id = xor_bytes(packed_id, xxh3(packed_namespace + s))
      encoded_namespace = xor_bytes(packed_namespace, xxh3(s))

      uuid_bytes = encoded_namespace[0..3] + encoded_id[0..1] + s[0..3] + encoded_id[2..7]
      format_uuid(uuid_bytes)
    end

    def decode(uuid_string)
      raise NotImplementedError, "decode not yet implemented"
    end

    module_function

    # XOR two equal-length binary strings byte-by-byte
    def xor_bytes(a, b)
      a.bytes.zip(b.bytes).map { |x, y| x ^ y }.pack("C*")
    end

    # Returns 8-byte raw binary digest (matches PHP hash('xxh3', msg, true))
    def xxh3(message)
      Digest::XXH3_64bits.digest(message)
    end

    # Returns 4-byte big-endian seed with UUIDv8 version+variant bits embedded
    def compute_seed(packed_id, packed_namespace)
      h = xxh3(packed_id + packed_namespace)
      val = h[0..3].unpack1("N")
      masked = (val & 0x0FFF3FFF) | 0x80008000
      [masked].pack("N")
    end

    # Format 16 raw bytes as UUID string
    def format_uuid(bytes)
      hex = bytes.unpack1("H*")
      "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
    end

    # Parse UUID string to 16 raw bytes; returns nil if not a valid UUIDv8
    def parse_uuid(uuid_string)
      return nil unless uuid_string.is_a?(String) && uuid_string.match?(VALIDATION_REGEX)

      [uuid_string.delete("-")].pack("H*")
    end
  end
end
