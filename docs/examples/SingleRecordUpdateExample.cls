/**
 * Example: Single record update with TrackedRecord.
 *
 * This service demonstrates the simplest TrackedRecord usage — updating one
 * field on one Account record without touching any other fields.
 *
 * The benefit: even if another user is concurrently editing this Account,
 * their changes to other fields are preserved because we only write the
 * field we explicitly set.
 *
 * Note: This file is for documentation only and is excluded from package
 * deployment via .forceignore. Copy and adapt to your own service classes.
 *
 * @see https://github.com/alarussaj/apex-tracked-record
 */
public inherited sharing class SingleRecordUpdateExample {
	/**
	 * Updates the Industry on a single Account, leaving all other fields untouched.
	 *
	 * @param accountId The Id of the Account to update.
	 * @param newIndustry The new industry value.
	 */
	public static void updateIndustry(Id accountId, String newIndustry) {
		// Query only the fields we need to read (plus Id, always required for updates)
		Account account = [
			SELECT Id, Industry
			FROM Account
			WHERE Id = :accountId
			LIMIT 1
		];

		// Wrap the queried record
		TrackedRecord tracked = TrackedRecord.wrap(account);

		// Use setIfChanged to skip the update entirely if the value hasn't changed.
		// This avoids unnecessary DML, trigger runs, and audit-trail churn.
		tracked.setIfChanged(Account.Industry, newIndustry);

		// Only DML if something actually changed
		if (tracked.isDirty()) {
			update tracked.toDmlRecord();
		}
	}

	/**
	 * Updates multiple fields on a single Account using method chaining.
	 *
	 * @param accountId The Id of the Account to update.
	 * @param newIndustry The new industry value.
	 * @param newEmployeeCount The new employee count.
	 */
	public static void updateAccountSummary(Id accountId, String newIndustry, Integer newEmployeeCount) {
		Account account = [
			SELECT Id, Industry, NumberOfEmployees
			FROM Account
			WHERE Id = :accountId
			LIMIT 1
		];

		TrackedRecord tracked = TrackedRecord.wrap(account)
			.setIfChanged(Account.Industry, newIndustry)
			.setIfChanged(Account.NumberOfEmployees, newEmployeeCount);

		if (tracked.isDirty()) {
			update tracked.toDmlRecord();
		}
	}
}
