/**
 * Example: Integrating TrackedRecord with a Unit of Work (UoW).
 *
 * TrackedRecord is UoW-agnostic — it doesn't perform DML itself, so you
 * can pair it with any UoW implementation (fflib, ThinkSDK's UnitOfWork,
 * a custom Map-based collector, etc.). This example shows the integration
 * pattern using the registerDirty(SObject, List<SObjectField>) signature
 * that fflib's UoW provides.
 *
 * The benefit: TrackedRecord captures field-level changes (the *what*),
 * and the UoW handles transaction boundaries and DML coordination
 * (the *when* and *how*).
 *
 * Note: This example assumes an fflib-style UoW. The same pattern works
 * with any UoW that accepts SObject + dirty field list. This file is for
 * documentation only and is excluded from package deployment via
 * .forceignore.
 *
 * @see https://github.com/alarussaj/apex-tracked-record
 */
public inherited sharing class UnitOfWorkIntegrationExample {
	/**
	 * Stub interface representing a Unit of Work that supports field-level
	 * dirty tracking. In your real codebase, replace this with your actual
	 * UoW interface (e.g., fflib_ISObjectUnitOfWork from fflib-apex-common).
	 */
	public interface ISimpleUnitOfWork {
		void registerDirty(SObject record, List<SObjectField> dirtyFields);
		void commitWork();
	}

	/**
	 * Updates Account records via a UoW. The UoW handles the transaction;
	 * TrackedRecord ensures only the dirty fields are written.
	 *
	 * @param uow The Unit of Work to register changes against.
	 * @param accountIds The Ids of Accounts to update.
	 * @param newIndustry The new industry value to apply.
	 */
	public static void updateViaUoW(ISimpleUnitOfWork uow, Set<Id> accountIds, String newIndustry) {
		List<Account> accounts = [
			SELECT Id, Industry, NumberOfEmployees
			FROM Account
			WHERE Id IN :accountIds
		];

		List<TrackedRecord> tracked = TrackedRecord.wrapAll(accounts);
		for (TrackedRecord trackedRecord : tracked) {
			Account acct = (Account) trackedRecord.getRecord();

			// Only flag for industry change if it differs
			trackedRecord.setIfChanged(Account.Industry, newIndustry);

			// Conditional change based on size
			if (acct.NumberOfEmployees != null && acct.NumberOfEmployees >= 100) {
				trackedRecord.set(Account.Description, 'Mid-Market or larger');
			}

			// Register with the UoW only if there's something to write.
			// getRecord() returns the original SObject (UoW will pull the Id).
			// getDirtyFieldList() returns the list of fields the UoW should write.
			if (trackedRecord.isDirty()) {
				uow.registerDirty(trackedRecord.getRecord(), trackedRecord.getDirtyFieldList());
			}
		}

		// UoW handles the actual DML, transaction boundaries, error handling
		uow.commitWork();
	}

	/**
	 * Alternative integration pattern: direct DML record handoff.
	 *
	 * If your UoW accepts a fully-formed SObject (not the dirty-fields style),
	 * use toDmlRecord() instead. The UoW will simply DML the supplied record,
	 * which already contains only the Id and dirty fields.
	 *
	 * @param uow The Unit of Work to register against.
	 * @param accountIds The Ids of Accounts to update.
	 */
	public static void updateViaUoWDirect(ISimpleUnitOfWork uow, Set<Id> accountIds) {
		List<Account> accounts = [SELECT Id, Industry FROM Account WHERE Id IN :accountIds];

		List<TrackedRecord> tracked = TrackedRecord.wrapAll(accounts);
		for (TrackedRecord trackedRecord : tracked) {
			trackedRecord.setIfChanged(Account.Industry, 'Updated via UoW');
		}

		// toDmlRecords() filters to only dirty records and returns ready-to-DML SObjects
		List<SObject> toUpdate = TrackedRecord.toDmlRecords(tracked);
		for (SObject record : toUpdate) {
			// Pass the (already narrow) DML record to the UoW. Most UoWs accept
			// a List<SObjectField> too — pass an empty list since the SObject
			// is already filtered.
			uow.registerDirty(record, new List<SObjectField>());
		}

		uow.commitWork();
	}
}
