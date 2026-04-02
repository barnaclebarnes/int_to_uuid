# int_to_uuid

Bidirectionally encode a non-negative 64-bit integer ID and an optional 32-bit namespace into a valid [RFC 9562 Version 8 UUID](https://www.rfc-editor.org/rfc/rfc9562#section-5.8) — and decode it back.

This is useful for presenting auto-incrementing database IDs as opaque, non-sequential UUIDs in public-facing APIs without persisting the UUID itself.

Ruby port of [wickedbyte/int-to-uuid](https://github.com/wickedbyte/int-to-uuid) (PHP). Cross-language compatible: the same integer produces the same UUID in both implementations.

## Installation

Add to your Gemfile:

```ruby
gem "int_to_uuid"
```

Or install directly:

```
gem install int_to_uuid
```

## Usage

### Encode

```ruby
require "int_to_uuid"

# Encode an integer to a UUID string
IntToUuid.encode(42)
# => "99c45a05-a33b-8544-8024-f4be69401069"

# Encode with a namespace (isolates ID spaces — e.g. users vs posts)
IntToUuid.encode(42, namespace: 12)
# => "dee5e9d2-c3e4-8273-b0d5-b3b5307bf749"

# You can also pass an IntegerId object directly
id = IntToUuid::IntegerId.new(42, namespace: 12)
IntToUuid.encode(id)
# => "dee5e9d2-c3e4-8273-b0d5-b3b5307bf749"
```

### Decode

```ruby
result = IntToUuid.decode("dee5e9d2-c3e4-8273-b0d5-b3b5307bf749")
result.value      # => 42
result.namespace  # => 12

# Raises ArgumentError for invalid or non-UUIDv8 strings
IntToUuid.decode("not-a-uuid")          # => ArgumentError
IntToUuid.decode("550e8400-e29b-41d4-a716-446655440000")  # => ArgumentError (v4, not v8)

# Raises ArgumentError if the checksum doesn't match (tampered UUID)
IntToUuid.decode("99c45a05-a33b-8544-8024-f4be69401068")  # => ArgumentError
```

## Ranges

| Parameter   | Type    | Range                    |
|-------------|---------|--------------------------|
| `value`     | Integer | 0 – 9,223,372,036,854,775,807 (2⁶³ − 1) |
| `namespace` | Integer | 0 – 4,294,967,295 (2³² − 1), default 0 |

Values outside these ranges raise `ArgumentError`.

## Why UUIDv8?

UUIDv8 is the RFC 9562 "custom" variant — its bytes are entirely application-defined. This library uses that freedom to embed the integer and namespace with a checksum that makes decoding reliable and tamper-detectable. The bitmask applied to the seed ensures the version nibble (`8`) and variant bits (`10xx`) are always correct, so the output is a valid UUIDv8 by construction.

## How it works

Encoding uses [XXH3](https://xxhash.com/) (64-bit) to scramble the integer and namespace before packing them into the 16 UUID bytes. A 4-byte seed is derived from both inputs and stored in the UUID itself, enabling decoding without any external state. The seed also carries the UUIDv8 version and variant bits.

The UUID layout is:

```
xxxxxxxx-xxxx-8xxx-[89ab]xxx-xxxxxxxxxxxx
│               │   │        │
encoded_ns[0..3] │   seed     encoded_id[2..7]
          encoded_id[0..1]
```

## Requirements

- Ruby >= 3.1
- [`digest-xxhash`](https://rubygems.org/gems/digest-xxhash) (C extension, installed automatically)

## Development

```
bundle install
bundle exec rake test
```

## License

MIT
