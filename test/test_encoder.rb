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

  # --- Decode: test vectors ---

  def test_decode_vectors
    VECTORS.each do |v|
      result = IntToUuid.decode(v["uuid"])
      assert_equal v["id"], result.value,
        "decode(#{v["uuid"]}) expected id=#{v["id"]}, got #{result.value}"
      assert_equal v["namespace"], result.namespace,
        "decode(#{v["uuid"]}) expected namespace=#{v["namespace"]}, got #{result.namespace}"
    end
  end

  # --- Round-trip ---

  def test_roundtrip_boundary_values
    pairs = [
      [0, 0],
      [0, IntToUuid::IntegerId::NAMESPACE_MAX],
      [IntToUuid::IntegerId::ID_MAX, 0],
      [IntToUuid::IntegerId::ID_MAX, IntToUuid::IntegerId::NAMESPACE_MAX]
    ]
    pairs.each do |id, ns|
      uuid = IntToUuid.encode(id, namespace: ns)
      result = IntToUuid.decode(uuid)
      assert_equal id, result.value, "round-trip id mismatch for (#{id}, #{ns})"
      assert_equal ns, result.namespace, "round-trip namespace mismatch for (#{id}, #{ns})"
    end
  end

  def test_roundtrip_random_pairs
    rng = Random.new(42)
    100.times do
      id = rng.rand(0..IntToUuid::IntegerId::ID_MAX)
      ns = rng.rand(0..IntToUuid::IntegerId::NAMESPACE_MAX)
      uuid = IntToUuid.encode(id, namespace: ns)
      result = IntToUuid.decode(uuid)
      assert_equal id, result.value, "round-trip id mismatch for (#{id}, #{ns})"
      assert_equal ns, result.namespace, "round-trip namespace mismatch for (#{id}, #{ns})"
    end
  end

  # --- Decode validation ---

  def test_decode_rejects_nil
    assert_raises(ArgumentError) { IntToUuid.decode(nil) }
  end

  def test_decode_rejects_empty_string
    assert_raises(ArgumentError) { IntToUuid.decode("") }
  end

  def test_decode_rejects_malformed_string
    assert_raises(ArgumentError) { IntToUuid.decode("not-a-uuid") }
  end

  def test_decode_rejects_uuidv4
    assert_raises(ArgumentError) { IntToUuid.decode("550e8400-e29b-41d4-a716-446655440000") }
  end

  def test_decode_rejects_nil_uuid
    assert_raises(ArgumentError) { IntToUuid.decode("00000000-0000-0000-0000-000000000000") }
  end

  def test_decode_rejects_tampered_uuid
    # Valid format but seed checksum won't match
    assert_raises(ArgumentError) { IntToUuid.decode("99c45a05-a33b-8544-8024-f4be69401068") }
  end
end
