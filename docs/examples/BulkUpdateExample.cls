/**
 * Example: Bulk update with conditional, per-record logic.
 *
 * This service demonstrates updating many records where each record may
 * have different fields changed based on its current state. TrackedRecord
 * captures the per-record changes and toDmlRecords() produces a clean
 * DML list with only the records that actually need updating.
 *
 * The benefit: bulk operations stay narrow. Records that don't need
 * changes never hit the database, and records that do need changes
 * only write the fields that actually changed.
 *
 * Note: This file is for documentation only and is excluded from package
 * deployment via .forceignore. Copy and adapt to your own service classes.
 *
 * @see https://github.com/alarussaj/apex-tracked-record
 */
public inherited sharing class BulkUpdateExample {
	/**
	 * Categorizes Accounts by employee count and industry. Each Account may
	 * have different fields changed (or none at all). Only Accounts with
	 * actual changes are sent to DML.
	 *
	 * @param accountIds The Ids of Accounts to evaluate and potentially update.
	 */
	public static void categorizeAccounts(Set<Id> accountIds) {
		// Query everything we'll need to evaluate
		List<Account> accounts = [
			SELECT Id, Industry, NumberOfEmployees, Description
			FROM Account
			WHERE Id IN :accountIds
		];

		// Wrap them all up front
		List<TrackedRecord> tracked = TrackedRecord.wrapAll(accounts);

		// Apply per-record logic — different rules for different records
		for (TrackedRecord trackedRecord : tracked) {
			Account acct = (Account) trackedRecord.getRecord();

			// Rule 1: Set the segment marker based on size
			if (acct.NumberOfEmployees != null) {
				String segment = computeSegment(acct.NumberOfEmployees);
				trackedRecord.setIfChanged(Account.Description, segment);
			}

			// Rule 2: Default Industry if missing
			if (acct.Industry == null) {
				trackedRecord.set(Account.Industry, 'Unspecified');
			}
		}

		// toDmlRecords() filters out non-dirty wrappers automatically
		List<SObject> toUpdate = TrackedRecord.toDmlRecords(tracked);

		if (!toUpdate.isEmpty()) {
			// Use User Mode to enforce FLS, CRUD, and sharing rules
			Database.update(toUpdate, false, AccessLevel.USER_MODE);
		}
	}

	/**
	 * Returns a segment label based on employee count.
	 *
	 * @param employees The Account.NumberOfEmployees value.
	 * @return A descriptive segment label.
	 */
	private static String computeSegment(Integer employees) {
		if (employees >= 1000)
			return 'Enterprise';
		if (employees >= 100)
			return 'Mid-Market';
		if (employees >= 10)
			return 'Small Business';
		return 'Startup';
	}
}
