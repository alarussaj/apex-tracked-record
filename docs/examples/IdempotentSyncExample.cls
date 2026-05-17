/**
 * Example: Idempotent sync from external data source.
 *
 * This pattern is the classic motivation for TrackedRecord. When syncing
 * data from an external system (CRM integration, partner data feed,
 * scheduled API import), most records won't actually have changed values.
 *
 * Without TrackedRecord, even unchanged records cause:
 *   - Unnecessary DML
 *   - Trigger and workflow runs
 *   - LastModifiedDate / LastModifiedById updates
 *   - Audit-trail entries
 *   - Rollups and formulas to recompute
 *
 * setIfChanged() makes the sync idempotent: if a record's values haven't
 * changed, it's a no-op for that record.
 *
 * Note: This file is for documentation only and is excluded from package
 * deployment via .forceignore. Copy and adapt to your own service classes.
 *
 * @see https://github.com/alarussaj/apex-tracked-record
 */
public inherited sharing class IdempotentSyncExample {
	/**
	 * Wrapper for incoming data from an external system.
	 * In real code this would be deserialized from JSON or read from a custom object.
	 */
	public class ExternalAccountData {
		public Id sfdcId;
		public String industry;
		public String phone;
		public String website;
		public Integer employeeCount;
	}

	/**
	 * Syncs incoming external data to existing Salesforce Accounts using
	 * SObjectField tokens. Use this pattern when the field set is known
	 * at compile time.
	 *
	 * Only records whose values actually differ from the external data
	 * are updated.
	 *
	 * @param incoming The list of incoming data records (one per Salesforce Account).
	 */
	public static void syncFromExternal(List<ExternalAccountData> incoming) {
		// Build a quick lookup so we can match incoming data to queried records
		Map<Id, ExternalAccountData> incomingById = new Map<Id, ExternalAccountData>();
		for (ExternalAccountData data : incoming) {
			incomingById.put(data.sfdcId, data);
		}

		// Query existing Salesforce records
		List<Account> existing = [
			SELECT Id, Industry, Phone, Website, NumberOfEmployees
			FROM Account
			WHERE Id IN :incomingById.keySet()
		];

		// Wrap each one and apply setIfChanged for each external field
		List<TrackedRecord> tracked = TrackedRecord.wrapAll(existing);
		for (TrackedRecord trackedRecord : tracked) {
			Account acct = (Account) trackedRecord.getRecord();
			ExternalAccountData data = incomingById.get(acct.Id);

			trackedRecord
				.setIfChanged(Account.Industry, data.industry)
				.setIfChanged(Account.Phone, data.phone)
				.setIfChanged(Account.Website, data.website)
				.setIfChanged(Account.NumberOfEmployees, data.employeeCount);
		}

		// toDmlRecords() returns only the records that have changed values
		List<SObject> toUpdate = TrackedRecord.toDmlRecords(tracked);

		if (!toUpdate.isEmpty()) {
			Database.update(toUpdate, false, AccessLevel.USER_MODE);
		}

		// Telemetry: log how many records were actually updated vs. skipped
		System.debug(
			'Sync complete: ' + toUpdate.size() + ' updated, ' + (existing.size() - toUpdate.size()) + ' unchanged'
		);
	}

	/**
	 * Syncs incoming external data using a dynamic field-to-value mapping.
	 * Use this pattern when the field set is determined at runtime — for
	 * example, when the integration is driven by Custom Metadata, the
	 * incoming payload is a generic JSON object, or different record
	 * subtypes carry different fields.
	 *
	 * The String overloads of set / setIfChanged accept the field API name
	 * directly, so the caller doesn't need to convert names to SObjectField
	 * tokens. Field describes are cached per SObjectType for the lifetime
	 * of the transaction, so this scales cheaply across many fields and
	 * records.
	 *
	 * @param incomingByRecordId Map of Account Id to a field-name → value map for that record.
	 */
	public static void syncFromFieldMapping(Map<Id, Map<String, Object>> incomingByRecordId) {
		// Query the records to be updated. In production, you'd query only the
		// columns you'll actually reference; for a generic example we keep this simple.
		List<Account> existing = [
			SELECT Id, Industry, Phone, Website, NumberOfEmployees
			FROM Account
			WHERE Id IN :incomingByRecordId.keySet()
		];

		List<TrackedRecord> tracked = TrackedRecord.wrapAll(existing);
		for (TrackedRecord trackedRecord : tracked) {
			Account acct = (Account) trackedRecord.getRecord();
			Map<String, Object> incomingFields = incomingByRecordId.get(acct.Id);
			if (incomingFields == null) {
				continue;
			}

			// Apply each incoming field by name; setIfChanged keeps the sync idempotent
			for (String fieldName : incomingFields.keySet()) {
				trackedRecord.setIfChanged(fieldName, incomingFields.get(fieldName));
			}
		}

		List<SObject> toUpdate = TrackedRecord.toDmlRecords(tracked);

		if (!toUpdate.isEmpty()) {
			Database.update(toUpdate, false, AccessLevel.USER_MODE);
		}

		System.debug(
			'Dynamic sync complete: ' +
				toUpdate.size() +
				' updated, ' +
				(existing.size() - toUpdate.size()) +
				' unchanged'
		);
	}
}
