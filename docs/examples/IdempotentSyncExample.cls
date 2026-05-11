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
	 * Syncs incoming external data to existing Salesforce Accounts.
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
			Account account = (Account) trackedRecord.getRecord();
			ExternalAccountData data = incomingById.get(account.Id);

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
}
