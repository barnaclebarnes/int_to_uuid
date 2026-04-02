# int_to_uuid Gem Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the `int_to_uuid` Ruby gem that bidirectionally encodes a uint64 ID + uint32 namespace into a valid UUIDv8 string.

**Architecture:** Pure Ruby with one runtime dependency (`digest-xxhash` for XXH3 hashing). Three files: `IntegerId` value object, `Encoder` with private helpers, and a thin `IntToUuid` module facade. Minitest test suite with cross-language test vectors.

**Tech Stack:** Ruby >= 3.1, `digest-xxhash` gem (XXH3 hashing), Minitest (tests), Rake (test runner).

**Key Verified Fact:** `Digest::XXH3_64bits.digest(msg)` produces byte-for-byte identical output to PHP's `hash('xxh3', $msg, true)`. All 4 spot-checked test vectors pass.

---

### Task 1: Gem scaffold

**Files:**
- Create: `int_to_uuid.gemspec`
- Create: `Gemfile`
- Create: `Rakefile`
- Create: `lib/int_to_uuid.rb`
- Create: `lib/int_to_uuid/version.rb`
- Create: `test/test_helper.rb`
- Create: `test/fixtures/test_vectors.json` (copy from `docs/test_vectors.json`)

**Step 1: Create `.ruby-version`**

```bash
echo "3.4.7" > .ruby-version
```

**Step 2: Create `lib/int_to_uuid/version.rb`**

```ruby
# frozen_string_literal: true

module IntToUuid
  VERSION = "0.1.0"
end
```

**Step 3: Create `int_to_uuid.gemspec`**

```ruby
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
```

**Step 4: Create `Gemfile`**

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :test do
  gem "minitest", "~> 5.0"
  gem "rake", "~> 13.0"
end
```

**Step 5: Create `Rakefile`**

```ruby
# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
end

task default: :test
```

**Step 6: Create `test/test_helper.rb`**

```ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "int_to_uuid"
```

**Step 7: Create `test/fixtures/` dir and copy test vectors**

```bash
mkdir -p test/fixtures
cp docs/test_vectors.json test/fixtures/test_vectors.json
```

**Step 8: Create stub `lib/int_to_uuid.rb`**

```ruby
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
```

**Step 9: Install dependencies**

```bash
bundle install
```

Expected: Fetches and installs `digest-xxhash`, `minitest`, `rake`.

**Step 10: Verify bundle runs**

```bash
bundle exec rake --tasks
```

Expected: Shows `rake test` task.

---

### Task 2: IntegerId value object

**Files:**
- Create: `lib/int_to_uuid/integer_id.rb`
- Create: `test/test_integer_id.rb`

**Step 1: Write the failing tests**

```ruby
# test/test_integer_id.rb
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
```

**Step 2: Run to verify it fails**

```bash
bundle exec ruby -Itest test/test_integer_id.rb
```

Expected: Error — `uninitialized constant IntToUuid::IntegerId`

**Step 3: Implement `lib/int_to_uuid/integer_id.rb`**

```ruby
# frozen_string_literal: true

module IntToUuid
  class IntegerId
    ID_MIN = 0
    ID_MAX = 2**63 - 1       # 9223372036854775807
    NAMESPACE_MIN = 0
    NAMESPACE_MAX = 2**32 - 1 # 4294967295

    attr_reader :value, :namespace

    def initialize(value, namespace: 0)
      unless value.is_a?(Integer) && value >= ID_MIN && value <= ID_MAX
        raise ArgumentError, "value must be an integer between #{ID_MIN} and #{ID_MAX}, got #{value.inspect}"
      end
      unless namespace.is_a?(Integer) && namespace >= NAMESPACE_MIN && namespace <= NAMESPACE_MAX
        raise ArgumentError, "namespace must be an integer between #{NAMESPACE_MIN} and #{NAMESPACE_MAX}, got #{namespace.inspect}"
      end

      @value = value
      @namespace = namespace
    end
  end
end
```

**Step 4: Run tests to verify they pass**

```bash
bundle exec ruby -Itest test/test_integer_id.rb
```

Expected: `10 runs, 10 assertions, 0 failures, 0 errors`

**Step 5: Commit**

```bash
git add lib/ test/ int_to_uuid.gemspec Gemfile Rakefile .ruby-version
git commit -m "feat: scaffold gem and implement IntegerId value object"
```

---

### Task 3: Encoder — private helpers

**Files:**
- Create: `lib/int_to_uuid/encoder.rb`

**Step 1: Create `lib/int_to_uuid/encoder.rb` with private helpers only (no encode/decode yet)**

```ruby
# frozen_string_literal: true

require "digest/xxhash"

module IntToUuid
  module Encoder
    module_function

    private

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

    # Parse UUID string to 16 raw bytes; returns nil if malformed
    def parse_uuid(uuid_string)
      return nil unless uuid_string.is_a?(String) && uuid_string.match?(VALIDATION_REGEX)

      [uuid_string.delete("-")].pack("H*")
    end
  end
end
```

No tests for private helpers directly — they're exercised through encode/decode.

---

### Task 4: Encoder — encode

**Files:**
- Modify: `lib/int_to_uuid/encoder.rb`
- Create: `test/test_encoder.rb`

**Step 1: Write failing encode tests (test vectors only)**

```ruby
# test/test_encoder.rb
# frozen_string_literal: true

require "test_helper"
require "json"

class TestEncoder < Minitest::Test
  VECTORS = JSON.parse(
    File.read(File.join(__dir__, "fixtures/test_vectors.json"))
  ).freeze

  # --- Encode: test vectors ---

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
```

**Step 2: Run to verify it fails**

```bash
bundle exec ruby -Itest test/test_encoder.rb
```

Expected: Error — `undefined method 'encode' for Encoder:Module` or similar.

**Step 3: Add `encode` to `lib/int_to_uuid/encoder.rb`**

Add these public methods inside `module Encoder` (before the `private` line):

```ruby
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
```

**Step 4: Run tests to verify they pass**

```bash
bundle exec ruby -Itest test/test_encoder.rb
```

Expected: `4 runs, 4 assertions, 0 failures, 0 errors` (37 vector checks inside test_encode_vectors).

**Step 5: Commit**

```bash
git add lib/int_to_uuid/encoder.rb test/test_encoder.rb
git commit -m "feat: implement IntToUuid.encode with test vector coverage"
```

---

### Task 5: Encoder — decode

**Files:**
- Modify: `lib/int_to_uuid/encoder.rb`
- Modify: `test/test_encoder.rb`

**Step 1: Add failing decode tests to `test/test_encoder.rb`**

Append these test methods to `TestEncoder`:

```ruby
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
```

**Step 2: Run to verify new tests fail**

```bash
bundle exec ruby -Itest test/test_encoder.rb
```

Expected: Failures for all decode-related tests.

**Step 3: Add `decode` to `lib/int_to_uuid/encoder.rb`** (inside `module Encoder`, before `private`)

```ruby
    def decode(uuid_string)
      bytes = parse_uuid(uuid_string)
      raise ArgumentError, "invalid UUIDv8 string: #{uuid_string.inspect}" if bytes.nil?

      # Extract components from UUID layout:
      # encoded_namespace[0..3] | encoded_id[0..1] | seed[0..3] | encoded_id[2..7]
      encoded_namespace = bytes[0..3]
      encoded_id_hi     = bytes[4..5]
      s                 = bytes[6..9]
      encoded_id_lo     = bytes[10..15]

      encoded_id = encoded_id_hi + encoded_id_lo

      packed_namespace = xor_bytes(encoded_namespace, xxh3(s))
      packed_id        = xor_bytes(encoded_id, xxh3(packed_namespace + s))

      # Verify checksum: recompute seed and compare
      expected_seed = compute_seed(packed_id, packed_namespace)
      raise ArgumentError, "UUID checksum invalid: #{uuid_string.inspect}" unless expected_seed == s

      id        = packed_id.unpack1("Q>")
      namespace = packed_namespace.unpack1("N")

      IntegerId.new(id, namespace: namespace)
    end
```

**Step 4: Run all tests to verify they pass**

```bash
bundle exec rake test
```

Expected: All tests pass — `0 failures, 0 errors`.

**Step 5: Commit**

```bash
git add lib/int_to_uuid/encoder.rb test/test_encoder.rb
git commit -m "feat: implement IntToUuid.decode with round-trip and validation tests"
```

---

### Task 6: Verify gem builds and run full suite

**Step 1: Run full test suite**

```bash
bundle exec rake test
```

Expected: All tests pass with 0 failures.

**Step 2: Build the gem**

```bash
gem build int_to_uuid.gemspec
```

Expected: `Successfully built RubyGem — Name: int_to_uuid, Version: 0.1.0`

**Step 3: Verify gem contents**

```bash
gem contents int_to_uuid-0.1.0.gem 2>/dev/null || tar tzf int_to_uuid-0.1.0.gem 2>/dev/null | head -20
```

Expected: Shows `lib/int_to_uuid.rb`, `lib/int_to_uuid/version.rb`, etc.

**Step 4: Final commit**

```bash
git add .
git commit -m "chore: verify gem builds cleanly"
```

---

## Summary

| Task | Files | Tests |
|------|-------|-------|
| 1. Scaffold | gemspec, Gemfile, Rakefile, lib stubs, test_helper | — |
| 2. IntegerId | `lib/int_to_uuid/integer_id.rb` | `test/test_integer_id.rb` (10 tests) |
| 3. Encoder helpers | `lib/int_to_uuid/encoder.rb` (private) | via encode/decode |
| 4. encode | encoder.rb (public encode) | test_encoder.rb vectors (37+3 checks) |
| 5. decode | encoder.rb (public decode) | test_encoder.rb decode+roundtrip+validation |
| 6. Polish | — | gem build |
