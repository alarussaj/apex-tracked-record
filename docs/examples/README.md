# TrackedRecord Examples

Complete, deployable Apex classes demonstrating TrackedRecord patterns. Each file is annotated with comments explaining the _why_ alongside the _what_.

## Files

| File                                                                 | Pattern                                                      |
| -------------------------------------------------------------------- | ------------------------------------------------------------ |
| [SingleRecordUpdateExample.cls](SingleRecordUpdateExample.cls)       | Updating one or more fields on a single record               |
| [BulkUpdateExample.cls](BulkUpdateExample.cls)                       | Bulk updates with per-record conditional logic               |
| [IdempotentSyncExample.cls](IdempotentSyncExample.cls)               | Syncing data from an external system without unnecessary DML |
| [UnitOfWorkIntegrationExample.cls](UnitOfWorkIntegrationExample.cls) | Integration with fflib-style Unit of Work patterns           |

## How to use these

These files are **examples**, not part of the deployed library. They are excluded from package deployment via `.forceignore`. To use them:

1. **Copy the file contents** into your own Apex codebase
2. **Adapt the class name and namespace** to your project's conventions
3. **Replace placeholder types** (e.g., `ExternalAccountData`, `ISimpleUnitOfWork`) with your real types

The patterns are deliberately general — they use only `Account` and standard fields so anyone can read and understand them, but the techniques apply to any SObject and any field combination.

## Where to start

If you're new to TrackedRecord, work through the examples in order:

1. **SingleRecordUpdateExample.cls** — the simplest possible usage
2. **BulkUpdateExample.cls** — scale up to lists of records
3. **IdempotentSyncExample.cls** — the highest-value real-world pattern
4. **UnitOfWorkIntegrationExample.cls** — when you need transaction coordination

After working through these, the [README](../../README.md) API reference will make sense and you can apply TrackedRecord to your own use cases.

## Found a pattern that's missing?

If you have a TrackedRecord usage pattern that isn't covered here and you think others would benefit from it, [open a pull request](https://github.com/alarussaj/apex-tracked-record/pulls) adding a new example. The bar is: would a new user have understood the pattern faster with this example present?
