# apex-tracked-record

[![PR Validation](https://github.com/alarussaj/apex-tracked-record/actions/workflows/pr-validation.yml/badge.svg)](https://github.com/alarussaj/apex-tracked-record/actions/workflows/pr-validation.yml)
[![CodeQL](https://github.com/alarussaj/apex-tracked-record/actions/workflows/codeql.yml/badge.svg)](https://github.com/alarussaj/apex-tracked-record/actions/workflows/codeql.yml)
[![codecov](https://codecov.io/gh/alarussaj/apex-tracked-record/branch/main/graph/badge.svg)](https://codecov.io/gh/alarussaj/apex-tracked-record)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Apex API: 64.0](https://img.shields.io/badge/Apex%20API-64.0-blue.svg)](#requirements)

> **Apex DML that only writes the fields you actually changed.**

`TrackedRecord` is a focused, lightweight Apex library for safe, narrow updates. It wraps an existing record, captures explicit `set()` calls, and produces a DML-ready SObject containing **only the Id and the fields that actually changed**.

This prevents the field clobbering and trigger amplification that occur when Apex DML writes every populated field on a record.

---

## Why TrackedRecord?

When you update an SObject in Apex, DML writes _every populated field_ on the record — even fields you never intended to change. This silently:

- Overwrites concurrent edits made by other users.
- Amplifies trigger execution (every workflow, validation rule, and trigger evaluating field changes sees changes that didn't logically happen).
- Wastes CPU on rollups, formulas, and downstream automation that recompute things based on changes that didn't really occur.

`TrackedRecord` solves this with a tiny, focused API. No DI container, no UoW dependency, no managed package required. Five public types, drops into any org as source.

---

## Installation

### Option 1: Unlocked Package (recommended for most users)

Install via package URL — no source deployment needed:

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=<PACKAGE_VERSION_ID>
```

> Replace `<PACKAGE_VERSION_ID>` with the latest version Id from the [Releases page](https://github.com/alarussaj/apex-tracked-record/releases).

For sandbox installation, replace `login.salesforce.com` with `test.salesforce.com`.

### Option 2: SFDX Source Deploy

```bash
git clone https://github.com/alarussaj/apex-tracked-record.git
cd apex-tracked-record
sf project deploy start --target-org <your-org-alias>
```

### Option 3: Git Submodule

For teams who want the source under version control alongside their own code:

```bash
git submodule add https://github.com/alarussaj/apex-tracked-record.git lib/apex-tracked-record
```

Then deploy `lib/apex-tracked-record/force-app` as part of your normal deploy.

---

## Quick Start

```apex
// Query the record(s) you want to update
List<Account> accounts = [
    SELECT Id, NumberOfEmployees, AnnualRevenue, Industry
    FROM Account
    WHERE Id IN :accountIds
];

// Wrap and apply changes
List<TrackedRecord> tracked = TrackedRecord.wrapAll(accounts);
for (TrackedRecord trackedRecord : tracked) {
    Account account = (Account) trackedRecord.getRecord();
    if (account.NumberOfEmployees != null && account.NumberOfEmployees >= 100) {
        trackedRecord.set(Account.IsPriority__c, true);
    }
    if (account.Industry == null) {
        trackedRecord.set(Account.Industry, 'Unknown');
    }
}

// DML only the records that actually changed, with only the fields that changed
List<SObject> toUpdate = TrackedRecord.toDmlRecords(tracked);
if (!toUpdate.isEmpty()) {
    Database.update(toUpdate, false, AccessLevel.USER_MODE);
}
```

---

## Usage

### Single record update

```apex
Account existing = [SELECT Id, Industry FROM Account WHERE Id = :accountId LIMIT 1];

TrackedRecord tracked = TrackedRecord.wrap(existing)
    .set(Account.Industry, 'Healthcare')
    .set(Account.NumberOfEmployees, 750);

if (tracked.isDirty()) {
    update tracked.toDmlRecord();
}
```

### Idempotent sync from external data

`setIfChanged()` skips records whose values haven't actually changed. No DML, no triggers, no audit-field churn.

```apex
List<TrackedRecord> tracked = TrackedRecord.wrapAll([
    SELECT Id, Industry, Phone, Website FROM Account WHERE Id IN :externalData.keySet()
]);

for (TrackedRecord trackedRecord : tracked) {
    Account account = (Account) trackedRecord.getRecord();
    ExternalAccount data = externalData.get(account.Id);
    trackedRecord
        .setIfChanged(Account.Industry, data.industry)
        .setIfChanged(Account.Phone, data.phone)
        .setIfChanged(Account.Website, data.website);
}

List<SObject> toUpdate = TrackedRecord.toDmlRecords(tracked);
if (!toUpdate.isEmpty()) {
    update toUpdate;
}
```

### Integration with a Unit of Work

`TrackedRecord` is UoW-agnostic — pass `toDmlRecord()` output to any UoW that accepts SObjects.

```apex
fflib_ISObjectUnitOfWork uow = Application.UnitOfWork.newInstance();

TrackedRecord tracked = TrackedRecord.wrap(existing)
    .set(Account.Industry, 'Healthcare');

if (tracked.isDirty()) {
    uow.registerDirty(tracked.getRecord(), tracked.getDirtyFieldList());
}

uow.commitWork();
```

### Custom equality rules

Implement `IFieldComparator` for domain-specific equality (e.g., trim whitespace, treat empty strings as null).

```apex
public class DomainAwareComparator implements IFieldComparator {
    public Boolean areEqual(Object a, Object b) {
        if (a instanceof String) a = String.isBlank((String) a) ? null : ((String) a).trim();
        if (b instanceof String) b = String.isBlank((String) b) ? null : ((String) b).trim();
        return DefaultFieldComparator.INSTANCE.areEqual(a, b);
    }
}

TrackedRecord tracked = TrackedRecord.wrap(existing).withComparator(new DomainAwareComparator());
```

---

## API Reference

| Method                              | Description                                                |
| ----------------------------------- | ---------------------------------------------------------- |
| `wrap(SObject)`                     | Wraps a record. Throws if record is null or has a null Id. |
| `wrapAll(List<SObject>)`            | Wraps a list of records.                                   |
| `set(field, value)`                 | Tracks a field as dirty (always).                          |
| `setIfChanged(field, value)`        | Tracks only if value differs from original.                |
| `clear(field)`                      | Removes a tracked change for a field.                      |
| `reset()`                           | Removes all tracked changes.                               |
| `getRecord()`                       | Returns the original wrapped SObject.                      |
| `getOriginal(field)`                | Returns the pre-change value of a field.                   |
| `isDirty()`                         | True if any field is tracked as changed.                   |
| `isFieldDirty(field)`               | True if the given field is tracked as changed.             |
| `getDirtyFields()`                  | Set of dirty fields (defensive copy).                      |
| `getDirtyFieldList()`               | List of dirty fields (for fflib integration).              |
| `getChangedValues()`                | Map of dirty field → new value (defensive copy).           |
| `toDmlRecord()`                     | SObject with Id + dirty fields only.                       |
| `toDmlRecords(List<TrackedRecord>)` | Static. List of DML records, filtered to dirty only.       |
| `withComparator(IFieldComparator)`  | Customize equality for `setIfChanged()`.                   |

See [TDD documentation](docs/) for detailed behavioral semantics and edge cases.

---

## Requirements

- Salesforce API version **64.0** or higher
- No external dependencies

---

## Versioning

This project follows [Semantic Versioning](https://semver.org/). Given a version number `MAJOR.MINOR.PATCH`:

- **MAJOR**: incompatible API changes.
- **MINOR**: backwards-compatible additions.
- **PATCH**: backwards-compatible bug fixes.

Pre-1.0 releases (`0.x.y`) are considered unstable; the API may change between minor versions until `1.0.0`. See [CHANGELOG.md](CHANGELOG.md) for release history.

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding standards, and the pull request process.

By participating, you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).

---

## License

MIT — see [LICENSE](LICENSE) for the full text.

---

## Author

Created and maintained by [Andrew J La Russa](https://github.com/alarussaj).

 
 
