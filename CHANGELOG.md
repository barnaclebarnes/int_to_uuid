# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-03

### Added

- `IntToUuid.encode(value, namespace: 0)` — encodes a 64-bit integer and optional 32-bit namespace into a UUIDv8 string
- `IntToUuid.decode(uuid_string)` — decodes a UUIDv8 string back to the original integer and namespace
- `IntToUuid::IntegerId` value object with range validation
- Cross-language compatibility with [wickedbyte/int-to-uuid](https://github.com/wickedbyte/int-to-uuid) (PHP), verified against 36 test vectors

[Unreleased]: https://github.com/barnaclebarnes/int_to_uuid/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/barnaclebarnes/int_to_uuid/releases/tag/v0.1.0
