# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

## [0.1.1] - 2026-05-16

First successful release. Adds String-name overloads for all field-accepting methods, enabling dynamic field updates from external data sources, custom metadata, or any runtime-determined field selection.

### Added
- String-name overloads for `set()`, `setIfChanged()`, `clear()`, `getOriginal()`, `getChangedValue()`, and `isFieldDirty()`. Each method now accepts either an `SObjectField` token or a field API name as a `String`.
- Per-SObjectType describe cache so multiple String-name lookups on records of the same type pay the describe cost only once per transaction.
- `IdempotentSyncExample.syncFromFieldMapping()` demonstrating dynamic field updates via the String-name overloads.

### Fixed
- Package compilation via `sf package version create` now succeeds. The previous v0.1.0 release attempt failed validation due to an Apex package compiler type-inference issue that misread `SObjectField` references in test contexts; the new String-name overloads resolve the ambiguity.
- `DefaultFieldComparator` now uses case-sensitive String equality (via `String.equals()`) instead of Apex's case-insensitive `==` operator. Strings like `'foo'` and `'FOO'` are now correctly treated as different, matching most users' expectations. Previously the case-insensitive behavior was silent and could cause `setIfChanged()` to skip changes that consumers expected to be tracked.

## [0.1.0] - Not Released

The v0.1.0 release attempt did not ship due to a package compilation issue. The fixes and additions are included in v0.1.1.

[Unreleased]: https://github.com/alarussaj/apex-tracked-record/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/alarussaj/apex-tracked-record/releases/tag/v0.1.1
