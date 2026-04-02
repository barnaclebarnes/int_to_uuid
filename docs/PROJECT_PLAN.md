# int_to_uuid Ruby Gem — Project Plan

## Overview

Port of the PHP library [wickedbyte/int-to-uuid](https://github.com/wickedbyte/int-to-uuid) to a Ruby gem. The library bidirectionally encodes a non-negative 64-bit unsigned integer ID and an optional 32-bit unsigned namespace integer into a valid RFC 9562 Version 8 UUID.

This is useful for presenting auto-incrementing database IDs as non-sequential, non-enumerable UUIDs in public-facing APIs — without needing to persist the UUID itself.

No existing Ruby gem provides this functionality (confirmed via RubyGems search, April 2026).

---

## Gem Metadata

- **Gem name:** `int_to_uuid`
- **Module namespace:** `IntToUuid`
- **Ruby version:** >= 3.1
- **License:** MIT
- **Dependencies:** None (pure Ruby, stdlib only)

---

## Algorithm Specification

### Hash Function

The PHP library uses **XXH3** (64-bit xxHash variant) via `hash('xxh3', $message, true)` which returns an 8-byte binary digest.

Ruby equivalent: Use the `digest` library or a bundled C extension. Since Ruby's stdlib does not include xxHash natively, we have two options:

1. **Option A (recommended):** Add `xxhash` gem as a runtime dependency — provides `XXhash.xxh3_64` which returns a 64-bit integer. We need the raw 8-byte big-endian binary output.
2. **Option B:** Vendor a pure-Ruby xxh3 implementation (slower but zero dependencies).

**Decision:** Go with **Option A** (`xxhash` gem). It's well-maintained, has C extensions for performance, and xxh3 is a non-trivial algorithm to implement in pure Ruby.

### Encoding Algorithm

Given `id` (uint64) and `namespace` (uint32, default 0):

```
1. Pack id as 8-byte big-endian unsigned 64-bit integer
2. Pack namespace as 4-byte big-endian unsigned 32-bit integer
3. Compute seed = seed(packed_id, packed_namespace)
4. XOR packed_id with hash(packed_namespace + seed)    → encoded_id (8 bytes)
5. XOR packed_namespace with hash(seed)                → encoded_namespace (4 bytes)
6. Assemble UUID bytes: encoded_namespace[0..3] + encoded_id[0..1] + seed[0..3] + encoded_id[2..7]
7. Format as standard UUID string: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Seed Generation

```
1. Compute hash(packed_id + packed_namespace) → 8 bytes
2. Take first 4 bytes, unpack as uint32 big-endian
3. Apply bitmask: (value & 0x0FFF3FFF) | 0x80008000
4. Pack result as 4-byte big-endian uint32
```

The bitmask embeds the RFC 9562 version (8) and variant (10xx) bits directly into the seed, so the final UUID is automatically a valid UUIDv8.

### Decoding Algorithm

Given a UUID string:

```
1. Validate UUID matches UUIDv8 format (version=8, variant=10xx)
2. Convert to 16 raw bytes
3. Extract: encoded_namespace = bytes[0..3], encoded_id_hi = bytes[4..5], seed = bytes[6..9], encoded_id_lo = bytes[10..15]
4. Reassemble encoded_id = encoded_id_hi + encoded_id_lo (8 bytes)
5. XOR encoded_namespace with hash(seed)                → packed_namespace
6. XOR encoded_id with hash(packed_namespace + seed)     → packed_id
7. Verify seed(packed_id, packed_namespace) == seed (checksum validation)
8. Unpack packed_id as uint64, packed_namespace as uint32
```

### Validation Regex

```
/^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
```

---

## Ruby Implementation Notes

### Binary Packing

- `[value].pack('Q>')` — uint64 big-endian (equivalent to PHP's `J` format)
- `[value].pack('N')` — uint32 big-endian (equivalent to PHP's `N` format)
- `str.unpack1('Q>')` — unpack uint64
- `str.unpack1('N')` — unpack uint32

### XOR on Binary Strings

Ruby doesn't support `^` on strings directly. Implement byte-wise XOR:

```ruby
def xor_bytes(a, b)
  a.bytes.zip(b.bytes).map { |x, y| x ^ y }.pack('C*')
end
```

Or more efficiently using `unpack`/`pack` with larger integer types when lengths are known (8 bytes → two uint32s or one uint64).

### XXH3 Hash

Using the `xxhash` gem:

```ruby
require 'xxhash'

def hash(message)
  digest = XXhash.xxh3_64(message)  # returns Integer
  [digest].pack('Q>')               # convert to 8-byte big-endian binary
end
```

**Important:** Verify that `XXhash.xxh3_64` with binary string input produces identical output to PHP's `hash('xxh3', ...)`. This is the critical compatibility point — write a cross-language verification test early.

### UUID Formatting

Convert 16 raw bytes to UUID string format:

```ruby
def format_uuid(bytes)
  hex = bytes.unpack1('H32')
  "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
end
```

Parse UUID string back to bytes:

```ruby
def parse_uuid(uuid_string)
  [uuid_string.delete('-')].pack('H32')
end
```

---

## File Structure

```
int_to_uuid/
├── Gemfile
├── Rakefile
├── LICENSE.txt
├── README.md
├── int_to_uuid.gemspec
├── lib/
│   ├── int_to_uuid.rb              # Main entry point, require hooks
│   └── int_to_uuid/
│       ├── version.rb              # IntToUuid::VERSION
│       ├── integer_id.rb           # IntToUuid::IntegerId value object
│       └── encoder.rb              # IntToUuid::Encoder (encode/decode logic)
├── test/
│   ├── test_helper.rb
│   ├── test_integer_id.rb          # IntegerId validation tests
│   ├── test_encoder.rb             # Encode/decode round-trip tests
│   └── fixtures/
│       └── test_vectors.json       # Cross-language compatibility vectors
└── docs/
    └── PROJECT_PLAN.md             # This file
```

---

## Public API Design

```ruby
require 'int_to_uuid'

# Encode an integer to a UUID string
uuid = IntToUuid.encode(42)
# => "99c45a05-a33b-8544-8024-f4be69401069"

# Encode with a namespace
uuid = IntToUuid.encode(42, namespace: 12)
# => "dee5e9d2-c3e4-8273-b0d5-b3b5307bf749"

# Decode a UUID back to id and namespace
result = IntToUuid.decode("dee5e9d2-c3e4-8273-b0d5-b3b5307bf749")
result.value      # => 42
result.namespace   # => 12

# IntegerId can also be constructed directly
id = IntToUuid::IntegerId.new(42, namespace: 12)
uuid = IntToUuid.encode(id)
```

### IntToUuid Module Methods

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `encode` | `(value_or_id, namespace: 0)` | `String` | Accepts an Integer or IntegerId; returns UUID string |
| `decode` | `(uuid_string)` | `IntegerId` | Parses and decodes a UUIDv8 string; raises on invalid input |

### IntToUuid::IntegerId

| Attribute | Type | Description |
|-----------|------|-------------|
| `value` | `Integer` | The encoded integer (0..2^63-1) |
| `namespace` | `Integer` | The namespace (0..2^32-1, default 0) |

Constants:
- `ID_MIN = 0`
- `ID_MAX = 2**63 - 1` (9223372036854775807)
- `NAMESPACE_MIN = 0`
- `NAMESPACE_MAX = 2**32 - 1` (4294967295)

Raises `ArgumentError` if values are out of range.

### Validation Regex

```ruby
IntToUuid::VALIDATION_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
```

---

## Test Plan

### Unit Tests (Minitest)

1. **IntegerId validation**
   - Valid construction with default namespace
   - Valid construction with explicit namespace
   - Rejects negative values
   - Rejects values > ID_MAX
   - Rejects namespace > NAMESPACE_MAX
   - Rejects negative namespace

2. **Encode/decode round-trip**
   - Round-trip for boundary values (0/0, 0/MAX, MAX/0, MAX/MAX)
   - Round-trip for 100+ random id/namespace pairs
   - Output matches UUIDv8 format regex
   - Output is lowercase hex with dashes

3. **Cross-language test vectors**
   - Load `test_vectors.json` (shared with PHP implementation)
   - Verify `encode(id, namespace)` produces exact UUID string
   - Verify `decode(uuid)` returns exact id and namespace

4. **Decode validation**
   - Rejects non-UUIDv8 strings (v4 UUIDs, nil UUID, max UUID)
   - Rejects valid UUIDv8 that doesn't contain a valid encoded ID (checksum mismatch)
   - Rejects malformed strings

5. **Edge cases**
   - `encode(0)` works and round-trips
   - `encode(ID_MAX)` works and round-trips
   - Large namespace values round-trip correctly

---

## Implementation Steps (for Claude Code)

### Phase 1: Scaffold
1. `bundle gem int_to_uuid` or manually create structure
2. Set up gemspec with metadata and `xxhash` dependency
3. Create `test_helper.rb` with minitest
4. Copy `test_vectors.json` into `test/fixtures/`

### Phase 2: Core Implementation
5. Implement `IntToUuid::IntegerId` value object with validation
6. Implement private helpers: `xor_bytes`, `hash`, `seed`, `format_uuid`, `parse_uuid`
7. Implement `IntToUuid.encode`
8. Implement `IntToUuid.decode`

### Phase 3: Test & Verify
9. Write and run IntegerId unit tests
10. Write and run encode/decode round-trip tests
11. Write and run test vector compatibility tests — **this is the critical gate**
12. Write and run decode validation/error tests

### Phase 4: Polish
13. Write README with usage examples and compatibility note
14. Ensure `rake test` passes cleanly
15. Ensure `gem build` succeeds

---

## Critical Risk: XXH3 Compatibility

The entire cross-language compatibility depends on the Ruby `xxhash` gem's `xxh3_64` producing identical output to PHP's `hash('xxh3', ...)` for the same binary input. Both should implement the reference xxHash algorithm, but this must be verified with the test vectors before proceeding past Phase 2.

If the `xxhash` gem doesn't support `xxh3_64`, alternatives include:
- `digest-xxhash` gem
- FFI binding to the xxHash C library
- The `ruby-xxHash` gem

Check gem availability and API at implementation time.
