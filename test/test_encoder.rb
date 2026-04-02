# frozen_string_literal: true

require "test_helper"
require "json"

class TestEncoder < Minitest::Test
  VECTORS = JSON.parse(
    File.read(File.join(__dir__, "fixtures/test_vectors.json"))
  ).freeze

  def test_encode_vectors
    VECTORS.each do |v|
      result = IntToUuid.encode(v["id"], namespace: v["namespace"])
      assert_equal v["uuid"], result,
        "encode(#{v["id"]}, namespace: #{v["namespace"]}) expected #{v["uuid"]}, got #{result}"
    end
  end

  def test_encode_produces_uuidv8_format
    VECTORS.each do |v|
      result = IntToUuid.encode(v["id"], namespace: v["namespace"])
      assert_match IntToUuid::VALIDATION_REGEX, result,
        "encode(#{v["id"]}, namespace: #{v["namespace"]}) produced invalid UUIDv8: #{result}"
    end
  end

  def test_encode_accepts_integer_id_object
    id = IntToUuid::IntegerId.new(42, namespace: 12)
    assert_equal "dee5e9d2-c3e4-8273-b0d5-b3b5307bf749", IntToUuid.encode(id)
  end

  def test_encode_default_namespace_is_zero
    assert_equal IntToUuid.encode(42, namespace: 0), IntToUuid.encode(42)
  end
end
