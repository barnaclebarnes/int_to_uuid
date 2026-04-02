# frozen_string_literal: true

require "test_helper"

class TestIntegerId < Minitest::Test
  def test_constructs_with_defaults
    id = IntToUuid::IntegerId.new(42)
    assert_equal 42, id.value
    assert_equal 0, id.namespace
  end

  def test_constructs_with_namespace
    id = IntToUuid::IntegerId.new(42, namespace: 12)
    assert_equal 42, id.value
    assert_equal 12, id.namespace
  end

  def test_value_zero_is_valid
    id = IntToUuid::IntegerId.new(0)
    assert_equal 0, id.value
  end

  def test_value_max_is_valid
    id = IntToUuid::IntegerId.new(IntToUuid::IntegerId::ID_MAX)
    assert_equal IntToUuid::IntegerId::ID_MAX, id.value
  end

  def test_namespace_max_is_valid
    id = IntToUuid::IntegerId.new(1, namespace: IntToUuid::IntegerId::NAMESPACE_MAX)
    assert_equal IntToUuid::IntegerId::NAMESPACE_MAX, id.namespace
  end

  def test_rejects_negative_value
    assert_raises(ArgumentError) { IntToUuid::IntegerId.new(-1) }
  end

  def test_rejects_value_above_max
    assert_raises(ArgumentError) { IntToUuid::IntegerId.new(IntToUuid::IntegerId::ID_MAX + 1) }
  end

  def test_rejects_negative_namespace
    assert_raises(ArgumentError) { IntToUuid::IntegerId.new(1, namespace: -1) }
  end

  def test_rejects_namespace_above_max
    assert_raises(ArgumentError) { IntToUuid::IntegerId.new(1, namespace: IntToUuid::IntegerId::NAMESPACE_MAX + 1) }
  end

  def test_constants
    assert_equal 0, IntToUuid::IntegerId::ID_MIN
    assert_equal 9223372036854775807, IntToUuid::IntegerId::ID_MAX
    assert_equal 0, IntToUuid::IntegerId::NAMESPACE_MIN
    assert_equal 4294967295, IntToUuid::IntegerId::NAMESPACE_MAX
  end
end
