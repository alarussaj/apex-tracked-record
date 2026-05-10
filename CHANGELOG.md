# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

## [0.1.0] - 2026-05-09

Initial release.

### Added
- `TrackedRecord` — wraps an existing SObject for field-level change tracking.
- `IFieldComparator` — strategy interface for customizing equality comparison in `setIfChanged()`.
- `DefaultFieldComparator` — null-safe, Decimal-scale-insensitive default comparator.
- `TrackedRecordException` — thrown on programmer-error inputs (null record, null Id, null field).
- `wrap(SObject)`, `wrapAll(List<SObject>)` factory methods.
- `set()`, `setIfChanged()`, `clear()`, `reset()` mutation API.
- `getRecord()`, `getOriginal(field)` reading API.
- `isDirty()`, `isFieldDirty(field)`, `getDirtyFields()`, `getDirtyFieldList()`, `getChangedValues()` state inspection.
- `toDmlRecord()`, `toDmlRecords(List<TrackedRecord>)` output for any UoW or direct DML.
- `withComparator(IFieldComparator)` for pluggable equality rules.

[Unreleased]: https://github.com/alarussaj/apex-tracked-record/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/alarussaj/apex-tracked-record/releases/tag/v0.1.0
