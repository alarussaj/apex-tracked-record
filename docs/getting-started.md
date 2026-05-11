# Getting Started with TrackedRecord

A 10-minute hands-on walkthrough. By the end you'll understand the core API and how to drop TrackedRecord into a real Apex codebase.

## Prerequisites

- A Salesforce org (sandbox, scratch, or Developer Edition) with TrackedRecord installed. See [Installation](../README.md#installation) in the main README.
- Permission to query and update Account records.

## What problem does this solve?

When you update an SObject in Apex, DML writes **every populated field** on the record — even fields you never explicitly changed. This silently:

- Overwrites concurrent edits made by other users
- Triggers automation (workflows, validation rules, triggers, flows) for fields that didn't logically change
- Wastes CPU on rollups, formulas, and downstream automation

A typical scenario:

```apex
// User A queries an Account and starts editing
Account account = [SELECT Id, Industry, Phone, Description FROM Account WHERE Id = :accountId];

// Meanwhile, User B updates account.Phone in another transaction (with their own DML)

// User A only intended to change Industry...
account.Industry = 'Healthcare';
update account;  // ← Silently overwrites User B's Phone change too
```

TrackedRecord prevents this by writing **only the fields you explicitly changed**.

## Step 1: Wrap a record

Query the record(s) you want to update. Wrap each one with `TrackedRecord.wrap()`:

```apex
Account account = [SELECT Id, Industry, Phone, NumberOfEmployees FROM Account LIMIT 1];
TrackedRecord tracked = TrackedRecord.wrap(account);
```

The wrapper holds a reference to your queried record. Reading fields on the original SObject still works through `tracked.getRecord()`:

```apex
Account a = (Account) tracked.getRecord();
System.debug('Industry: ' + a.Industry);
```

## Step 2: Make changes via `set()`

Use `set()` to track field-level changes. Each call records the change but does not write to the database yet:

```apex
tracked.set(Account.Industry, 'Healthcare');
tracked.set(Account.NumberOfEmployees, 250);
```

Methods chain, so you can also write:

```apex
tracked.set(Account.Industry, 'Healthcare')
       .set(Account.NumberOfEmployees, 250);
```

## Step 3: Check what changed

Before committing the update, inspect what the wrapper sees as dirty:

```apex
System.debug('Is dirty: ' + tracked.isDirty());
System.debug('Dirty fields: ' + tracked.getDirtyFields());
System.debug('Changes: ' + tracked.getChangedValues());
```

You can also query specific fields:

```apex
if (tracked.isFieldDirty(Account.Industry)) {
    System.debug('Industry changed from ' + tracked.getOriginal(Account.Industry));
}
```

## Step 4: Produce a DML record and update

`toDmlRecord()` returns a fresh SObject containing **only** the original `Id` and the dirty fields:

```apex
SObject dmlRecord = tracked.toDmlRecord();
update dmlRecord;
```

Verify what was actually written:

```apex
Account verifyAccount = [SELECT Id, Industry, Phone FROM Account WHERE Id = :account.Id];
System.assertEquals('Healthcare', verifyAccount.Industry);  // changed
System.assertEquals(account.Phone, verifyAccount.Phone);    // unchanged — preserved
```

## Step 5: Use `setIfChanged()` for idempotent updates

When syncing data from external systems, you often don't know whether a value has actually changed. `setIfChanged()` only tracks the field if the new value differs from the original:

```apex
TrackedRecord tracked = TrackedRecord.wrap(account);
tracked.setIfChanged(Account.Industry, externalSystem.industry);
tracked.setIfChanged(Account.Phone, externalSystem.phone);

if (tracked.isDirty()) {
    update tracked.toDmlRecord();
}
```

If `externalSystem.industry` happens to equal the existing `Industry`, `setIfChanged()` is a no-op for that field. Across thousands of records, this dramatically reduces unnecessary DML, trigger runs, and audit-trail churn.

## Step 6: Bulk updates

For lists of records, wrap them all and use `toDmlRecords()` to filter to only the dirty ones:

```apex
List<Account> accounts = [
    SELECT Id, Industry, NumberOfEmployees
    FROM Account
    WHERE Id IN :accountIds
];

List<TrackedRecord> tracked = TrackedRecord.wrapAll(accounts);
for (TrackedRecord trackedRecord : tracked) {
    Account account = (Account) trackedRecord.getRecord();
    if (account.NumberOfEmployees != null && account.NumberOfEmployees >= 100) {
        trackedRecord.set(Account.Industry, 'Enterprise');
    }
}

List<SObject> toUpdate = TrackedRecord.toDmlRecords(tracked);
if (!toUpdate.isEmpty()) {
    Database.update(toUpdate, false, AccessLevel.USER_MODE);
}
```

`TrackedRecord.toDmlRecords()` automatically filters out records that have no changes, so you only DML the records that actually need it.

## Where to next

- [Examples](examples/) — complete, deployable Apex classes for common patterns:
  - [Single record update](examples/SingleRecordUpdateExample.cls)
  - [Bulk update with conditional logic](examples/BulkUpdateExample.cls)
  - [Idempotent sync from external data](examples/IdempotentSyncExample.cls)
  - [Unit of Work integration](examples/UnitOfWorkIntegrationExample.cls)
- [README](../README.md) — full API reference and installation instructions
- [GitHub](https://github.com/alarussaj/apex-tracked-record) — issues, discussions, source

## Common questions

**Does TrackedRecord work with the Database class?**
Yes. `toDmlRecord()` returns a plain `SObject`, which works with `update`, `Database.update()`, `Database.upsert()`, or any DML mechanism.

**Does it work with fflib's Unit of Work?**
Yes. See [UnitOfWorkIntegrationExample.cls](examples/UnitOfWorkIntegrationExample.cls) for a worked example using `getDirtyFieldList()`.

**Can I track inserts?**
No. TrackedRecord is update-only by design — for inserts, plain SObject construction (`new Account(Name = '...')`) is the right answer because every field is intentional. TrackedRecord adds value only when you have an existing record and want to narrow the update scope.

**Is there a runtime overhead?**
Negligible. The wrapper is a thin object holding a reference to your SObject and a small Map of changed fields. No reflection, no describe calls, no SOQL.

**Can I customize equality comparison?**
Yes. Implement `IFieldComparator` and pass it to `withComparator()`. Useful for case-insensitive String comparison, treating empty strings as null, or any other domain-specific equality rule.
