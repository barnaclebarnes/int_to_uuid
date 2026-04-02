# frozen_string_literal: true

require_relative "lib/int_to_uuid/version"

Gem::Specification.new do |spec|
  spec.name = "int_to_uuid"
  spec.version = IntToUuid::VERSION
  spec.authors = ["barnaclebarnes"]
  spec.summary = "Bidirectionally encode a 64-bit integer ID into a UUIDv8 string"
  spec.description = "Port of wickedbyte/int-to-uuid. Encodes a non-negative 64-bit unsigned integer and an optional 32-bit namespace into a valid RFC 9562 Version 8 UUID."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "digest-xxhash", "~> 0.2"
end
