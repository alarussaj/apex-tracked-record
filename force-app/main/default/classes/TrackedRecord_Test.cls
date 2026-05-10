/**
 * @description Tests for TrackedRecord, IFieldComparator, and
 * DefaultFieldComparator. Covers construction validation, mutation
 * tracking, state queries, output (toDmlRecord / toDmlRecords),
 * and pluggable comparator behavior.
 *
 * No DML is performed; SObjects are constructed in-memory with
 * synthetic Ids derived from the SObject key prefix to avoid hardcoded
 * Id literals (PMD AvoidHardcodingId).
 *
 * @group TrackedRecord
 * @see https://github.com/alarussaj/apex-tracked-record
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
private class TrackedRecord_Test {
	/**
	 * @description Verifies wrap() throws TrackedRecordException when the
	 * supplied record is null, indicating a programmer error rather than a
	 * recoverable runtime condition.
	 */
	@IsTest
	static void shouldThrowWhenWrapReceivesNullRecord() {
		// Arrange
		Boolean threw = false;
		// Act
		try {
			TrackedRecord.wrap(null);
		} catch (TrackedRecordException e) {
			threw = true;
			Assert.isTrue(
				e.getMessage().contains('record must not be null'),
				'Failure message should explain that record cannot be null'
			);
		}
		// Assert
		Assert.isTrue(threw, 'wrap(null) should throw TrackedRecordException');
	}

	/**
	 * @description Verifies wrap() throws TrackedRecordException when the
	 * supplied record has no Id, ensuring TrackedRecord is only used for
	 * existing records.
	 */
	@IsTest
	static void shouldThrowWhenWrapReceivesRecordWithoutId() {
		// Arrange
		Account accountWithoutId = new Account(Name = 'Acme');
		Boolean threw = false;
		// Act
		try {
			TrackedRecord.wrap(accountWithoutId);
		} catch (TrackedRecordException e) {
			threw = true;
			Assert.isTrue(
				e.getMessage().contains('record.Id must not be null'),
				'Failure message should explain that the record must have an Id'
			);
		}
		// Assert
		Assert.isTrue(threw, 'wrap() should throw TrackedRecordException when record.Id is null');
	}

	/**
	 * @description Verifies wrapAll() throws TrackedRecordException when the
	 * supplied list is null.
	 */
	@IsTest
	static void shouldThrowWhenWrapAllReceivesNull() {
		// Arrange
		Boolean threw = false;
		// Act
		try {
			TrackedRecord.wrapAll(null);
		} catch (TrackedRecordException e) {
			threw = true;
		}
		// Assert
		Assert.isTrue(threw, 'wrapAll(null) should throw TrackedRecordException');
	}

	/**
	 * @description Verifies wrapAll() returns an empty list when given an
	 * empty input list, with no exception.
	 */
	@IsTest
	static void shouldReturnEmptyListWhenWrapAllReceivesEmptyList() {
		// Arrange
		List<SObject> emptyList = new List<SObject>();
		// Act
		List<TrackedRecord> result = TrackedRecord.wrapAll(emptyList);
		// Assert
		Assert.areEqual(0, result.size(), 'wrapAll(empty) should return an empty list');
	}

	/**
	 * @description Verifies wrapAll() preserves input order in the resulting list.
	 */
	@IsTest
	static void shouldPreserveOrderWhenWrapAllReceivesMultipleRecords() {
		// Arrange
		Account first = new Account(Id = fakeId(Account.SObjectType, 1), Name = 'First');
		Account second = new Account(Id = fakeId(Account.SObjectType, 2), Name = 'Second');
		// Act
		List<TrackedRecord> result = TrackedRecord.wrapAll(new List<SObject>{ first, second });
		// Assert
		Assert.areEqual(2, result.size(), 'Result should contain both wrapped records');
		Assert.areEqual(
			'First',
			((Account) result[0].getRecord()).Name,
			'First wrapped record should match first input'
		);
		Assert.areEqual(
			'Second',
			((Account) result[1].getRecord()).Name,
			'Second wrapped record should match second input'
		);
	}

	/**
	 * @description Verifies set() always tracks the field as dirty, regardless
	 * of whether the new value equals the current value.
	 */
	@IsTest
	static void shouldMarkFieldDirtyWhenSetIsCalled() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		// Act
		tracked.set(Account.Industry, 'Technology');
		// Assert
		Assert.isTrue(tracked.isDirty(), 'Wrapper should be dirty after set()');
		Assert.isTrue(tracked.isFieldDirty(Account.Industry), 'Industry should be flagged as dirty');
	}

	/**
	 * @description Verifies set() with the same value as currently on the
	 * record still marks the field dirty, since set() does not perform
	 * equality comparison.
	 */
	@IsTest
	static void shouldMarkFieldDirtyWhenSetReceivesEqualValue() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		account.Industry = 'Technology';
		TrackedRecord tracked = TrackedRecord.wrap(account);
		// Act
		tracked.set(Account.Industry, 'Technology');
		// Assert
		Assert.isTrue(tracked.isFieldDirty(Account.Industry), 'set() should track regardless of equality');
	}

	/**
	 * @description Verifies set() with a null value tracks the field as
	 * dirty so the DML record will explicitly clear that field on update.
	 */
	@IsTest
	static void shouldTrackNullValueWhenSetReceivesNull() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		account.Industry = 'Technology';
		TrackedRecord tracked = TrackedRecord.wrap(account);
		// Act
		tracked.set(Account.Industry, null);
		// Assert
		Assert.isTrue(tracked.isFieldDirty(Account.Industry), 'set(null) should track the field for clearing');
		Assert.areEqual(null, tracked.getChangedValues().get(Account.Industry), 'Changed value should be null');
	}

	/**
	 * @description Verifies set() throws TrackedRecordException when the
	 * field argument is null.
	 */
	@IsTest
	static void shouldThrowWhenSetReceivesNullField() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		Boolean threw = false;
		// Act
		try {
			tracked.set(null, 'value');
		} catch (TrackedRecordException e) {
			threw = true;
		}
		// Assert
		Assert.isTrue(threw, 'set(null, value) should throw TrackedRecordException');
	}

	/**
	 * @description Verifies setIfChanged() does not track the field when the
	 * proposed value equals the original value, providing idempotent updates.
	 */
	@IsTest
	static void shouldSkipTrackingWhenSetIfChangedReceivesEqualValue() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		account.Industry = 'Technology';
		TrackedRecord tracked = TrackedRecord.wrap(account);
		// Act
		tracked.setIfChanged(Account.Industry, 'Technology');
		// Assert
		Assert.isFalse(tracked.isDirty(), 'setIfChanged should skip equal values');
	}

	/**
	 * @description Verifies setIfChanged() tracks the field when the proposed
	 * value differs from the original value.
	 */
	@IsTest
	static void shouldTrackChangeWhenSetIfChangedReceivesDifferentValue() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		account.Industry = 'Technology';
		TrackedRecord tracked = TrackedRecord.wrap(account);
		// Act
		tracked.setIfChanged(Account.Industry, 'Healthcare');
		// Assert
		Assert.isTrue(tracked.isFieldDirty(Account.Industry), 'setIfChanged should track when values differ');
	}

	/**
	 * @description Verifies setIfChanged() always compares against the
	 * original value, not against the current effective (already-set) value,
	 * so the dirty result is independent of call order.
	 */
	@IsTest
	static void shouldCompareAgainstOriginalWhenSetIfChangedFollowsSet() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		account.Industry = 'Technology';
		TrackedRecord tracked = TrackedRecord.wrap(account);
		// Act
		tracked.set(Account.Industry, 'Healthcare');
		tracked.setIfChanged(Account.Industry, 'Technology');
		// Assert
		Assert.isTrue(tracked.isFieldDirty(Account.Industry), 'Field should remain dirty');
		Assert.areEqual(
			'Healthcare',
			tracked.getChangedValues().get(Account.Industry),
			'setIfChanged should not overwrite earlier set() because comparison uses the original'
		);
	}

	/**
	 * @description Verifies clear() removes a previously-tracked change for
	 * the given field, restoring the wrapper as if the field were never set.
	 */
	@IsTest
	static void shouldRemoveTrackedChangeWhenClearIsCalled() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		tracked.set(Account.Industry, 'Technology');
		// Act
		tracked.clear(Account.Industry);
		// Assert
		Assert.isFalse(tracked.isFieldDirty(Account.Industry), 'Field should no longer be dirty after clear()');
		Assert.isFalse(tracked.isDirty(), 'Wrapper should not be dirty if all changes are cleared');
	}

	/**
	 * @description Verifies clear() is a no-op when the field was not dirty,
	 * and does not throw.
	 */
	@IsTest
	static void shouldNoOpWhenClearIsCalledOnCleanField() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		// Act
		tracked.clear(Account.Industry);
		// Assert
		Assert.isFalse(tracked.isDirty(), 'Wrapper should not be dirty after clearing a clean field');
	}

	/**
	 * @description Verifies reset() removes all tracked changes, returning
	 * the wrapper to its initial state.
	 */
	@IsTest
	static void shouldRemoveAllChangesWhenResetIsCalled() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		tracked.set(Account.Industry, 'Technology');
		tracked.set(Account.NumberOfEmployees, 500);
		// Act
		tracked.reset();
		// Assert
		Assert.isFalse(tracked.isDirty(), 'Wrapper should not be dirty after reset()');
		Assert.areEqual(0, tracked.getDirtyFields().size(), 'Dirty fields should be empty after reset()');
	}

	/**
	 * @description Verifies reset() is a no-op on a clean wrapper.
	 */
	@IsTest
	static void shouldNoOpWhenResetIsCalledOnCleanWrapper() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		// Act
		tracked.reset();
		// Assert
		Assert.isFalse(tracked.isDirty(), 'Wrapper should remain not dirty');
	}

	/**
	 * @description Verifies getRecord() returns the same SObject reference
	 * that was originally wrapped, unchanged.
	 */
	@IsTest
	static void shouldReturnOriginalSObjectWhenGetRecordIsCalled() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		TrackedRecord tracked = TrackedRecord.wrap(account);
		// Act
		SObject returned = tracked.getRecord();
		// Assert
		Assert.areEqual(account, returned, 'getRecord() should return the same SObject reference that was wrapped');
	}

	/**
	 * @description Verifies getOriginal() returns the original (pre-change)
	 * field value even after set() has been called for that field.
	 */
	@IsTest
	static void shouldReturnPreChangeValueWhenGetOriginalIsCalled() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		account.Industry = 'Technology';
		TrackedRecord tracked = TrackedRecord.wrap(account);
		tracked.set(Account.Industry, 'Healthcare');
		// Act
		Object originalValue = tracked.getOriginal(Account.Industry);
		// Assert
		Assert.areEqual('Technology', originalValue, 'getOriginal() should return the pre-change value');
	}

	/**
	 * @description Verifies isDirty() and isFieldDirty() reflect tracked
	 * changes accurately.
	 */
	@IsTest
	static void shouldReflectTrackedChangesWhenStateIsQueried() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		// Assert (initial state)
		Assert.isFalse(tracked.isDirty(), 'Wrapper should start not dirty');
		Assert.isFalse(tracked.isFieldDirty(Account.Industry), 'Industry should not start dirty');
		// Act
		tracked.set(Account.Industry, 'Technology');
		// Assert (after set)
		Assert.isTrue(tracked.isDirty(), 'Wrapper should be dirty after set()');
		Assert.isTrue(tracked.isFieldDirty(Account.Industry), 'Industry should be dirty after set()');
		Assert.isFalse(tracked.isFieldDirty(Account.NumberOfEmployees), 'Other fields should remain not dirty');
	}

	/**
	 * @description Verifies getDirtyFields() returns a defensive copy that
	 * cannot be used to mutate the wrapper's internal state.
	 */
	@IsTest
	static void shouldReturnDefensiveCopyWhenGetDirtyFieldsIsCalled() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		tracked.set(Account.Industry, 'Technology');
		// Act
		Set<SObjectField> firstCall = tracked.getDirtyFields();
		firstCall.clear();
		Set<SObjectField> secondCall = tracked.getDirtyFields();
		// Assert
		Assert.areEqual(1, secondCall.size(), 'Mutating the returned set should not affect the wrapper');
	}

	/**
	 * @description Verifies getChangedValues() returns a defensive copy of
	 * the dirty field-to-value map.
	 */
	@IsTest
	static void shouldReturnDefensiveCopyWhenGetChangedValuesIsCalled() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		tracked.set(Account.Industry, 'Technology');
		// Act
		Map<SObjectField, Object> firstCall = tracked.getChangedValues();
		firstCall.clear();
		Map<SObjectField, Object> secondCall = tracked.getChangedValues();
		// Assert
		Assert.areEqual(1, secondCall.size(), 'Mutating the returned map should not affect the wrapper');
	}

	/**
	 * @description Verifies getDirtyFieldList() returns the dirty fields as
	 * a List, suitable for fflib-style integrations expecting List<SObjectField>.
	 */
	@IsTest
	static void shouldReturnFieldListWhenGetDirtyFieldListIsCalled() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		tracked.set(Account.Industry, 'Technology');
		tracked.set(Account.NumberOfEmployees, 500);
		// Act
		List<SObjectField> dirtyList = tracked.getDirtyFieldList();
		// Assert
		Assert.areEqual(2, dirtyList.size(), 'Dirty field list should contain both set fields');
	}

	/**
	 * @description Verifies toDmlRecord() returns an SObject containing only
	 * the original Id and the dirty fields, with no other fields populated.
	 */
	@IsTest
	static void shouldReturnRecordWithIdAndDirtyFieldsWhenToDmlRecordIsCalled() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		account.Industry = 'Technology';
		account.NumberOfEmployees = 100;
		TrackedRecord tracked = TrackedRecord.wrap(account);
		tracked.set(Account.Industry, 'Healthcare');
		// Act
		Account dmlRecord = (Account) tracked.toDmlRecord();
		// Assert
		Assert.areEqual(account.Id, dmlRecord.Id, 'DML record should preserve the original Id');
		Assert.areEqual('Healthcare', dmlRecord.Industry, 'DML record should contain the dirty Industry field');
		Map<String, Object> populated = dmlRecord.getPopulatedFieldsAsMap();
		Assert.areEqual(2, populated.size(), 'DML record should contain only Id and the one dirty field');
		Assert.isTrue(populated.containsKey('Id'), 'Populated fields should include Id');
		Assert.isTrue(populated.containsKey('Industry'), 'Populated fields should include the dirty Industry field');
		Assert.isFalse(populated.containsKey('Name'), 'Populated fields should not include Name (untracked)');
		Assert.isFalse(
			populated.containsKey('NumberOfEmployees'),
			'Populated fields should not include NumberOfEmployees (untracked)'
		);
	}

	/**
	 * @description Verifies toDmlRecord() on a clean wrapper returns an
	 * SObject containing only the Id with no other fields populated.
	 */
	@IsTest
	static void shouldReturnRecordWithOnlyIdWhenToDmlRecordIsCalledOnCleanWrapper() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		TrackedRecord tracked = TrackedRecord.wrap(account);
		// Act
		Account dmlRecord = (Account) tracked.toDmlRecord();
		// Assert
		Assert.areEqual(account.Id, dmlRecord.Id, 'DML record should preserve the Id');
		Assert.areEqual(1, dmlRecord.getPopulatedFieldsAsMap().size(), 'DML record should contain only the Id');
	}

	/**
	 * @description Verifies toDmlRecords() filters out non-dirty wrappers
	 * and null elements, returning only the DML records that should actually
	 * be persisted.
	 */
	@IsTest
	static void shouldFilterNonDirtyWhenToDmlRecordsIsCalled() {
		// Arrange
		TrackedRecord dirty = TrackedRecord.wrap(buildAccount(1, 'A'));
		dirty.set(Account.Industry, 'Technology');
		TrackedRecord clean = TrackedRecord.wrap(buildAccount(2, 'B'));
		TrackedRecord alsoDirty = TrackedRecord.wrap(buildAccount(3, 'C'));
		alsoDirty.set(Account.Industry, 'Healthcare');
		// Act
		List<SObject> result = TrackedRecord.toDmlRecords(new List<TrackedRecord>{ dirty, clean, alsoDirty });
		// Assert
		Assert.areEqual(2, result.size(), 'toDmlRecords should return only dirty wrappers');
	}

	/**
	 * @description Verifies toDmlRecords() returns an empty list for null
	 * input rather than throwing.
	 */
	@IsTest
	static void shouldReturnEmptyListWhenToDmlRecordsReceivesNull() {
		// Act
		List<SObject> result = TrackedRecord.toDmlRecords(null);
		// Assert
		Assert.areEqual(0, result.size(), 'toDmlRecords(null) should return an empty list');
	}

	/**
	 * @description Verifies withComparator() applies a custom equality rule
	 * end-to-end through setIfChanged().
	 */
	@IsTest
	static void shouldApplyCustomEqualityWhenWithComparatorIsCalled() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		account.Description = 'foo';
		TrackedRecord tracked = TrackedRecord.wrap(account).withComparator(new CaseInsensitiveComparator());
		// Act
		tracked.setIfChanged(Account.Description, 'FOO');
		// Assert
		Assert.isFalse(tracked.isDirty(), 'Custom case-insensitive comparator should treat foo and FOO as equal');
	}

	/**
	 * @description Verifies withComparator(null) restores the default
	 * comparator behavior.
	 */
	@IsTest
	static void shouldRestoreDefaultWhenWithComparatorReceivesNull() {
		// Arrange
		Account account = buildAccount(1, 'Acme');
		account.Description = 'foo';
		TrackedRecord tracked = TrackedRecord.wrap(account).withComparator(new CaseInsensitiveComparator());
		// Act
		tracked.withComparator(null);
		tracked.setIfChanged(Account.Description, 'FOO');
		// Assert
		Assert.isTrue(
			tracked.isDirty(),
			'After resetting to default comparator, foo and FOO should be treated as different'
		);
	}

	/**
	 * @description Verifies the default comparator treats Decimal values
	 * with different scales as equal (1.0 == 1.00).
	 */
	@IsTest
	static void shouldTreatDecimalScalesAsEqualWhenDefaultComparatorCompares() {
		// Arrange
		Decimal one = 1.0;
		Decimal oneScaled = 1.00;
		// Act
		Boolean result = DefaultFieldComparator.INSTANCE.areEqual(one, oneScaled);
		// Assert
		Assert.isTrue(result, 'Default comparator should treat 1.0 and 1.00 as equal');
	}

	/**
	 * @description Verifies the default comparator handles nulls correctly:
	 * two nulls are equal, one null and one non-null are not equal.
	 */
	@IsTest
	static void shouldHandleNullsCorrectlyWhenDefaultComparatorCompares() {
		// Act / Assert
		Assert.isTrue(DefaultFieldComparator.INSTANCE.areEqual(null, null), 'Two nulls should be equal');
		Assert.isFalse(DefaultFieldComparator.INSTANCE.areEqual(null, 'value'), 'Null and value should not be equal');
		Assert.isFalse(DefaultFieldComparator.INSTANCE.areEqual('value', null), 'Value and null should not be equal');
	}

	/**
	 * @description Verifies the default comparator returns true for two
	 * equal non-Decimal, non-null values via standard Apex equality.
	 */
	@IsTest
	static void shouldCompareValuesUsingStandardEqualityWhenDefaultComparatorReceivesNonDecimals() {
		// Act / Assert
		Assert.isTrue(DefaultFieldComparator.INSTANCE.areEqual('foo', 'foo'), 'Equal Strings should compare equal');
		Assert.isFalse(
			DefaultFieldComparator.INSTANCE.areEqual('foo', 'bar'),
			'Different Strings should compare unequal'
		);
		Assert.isTrue(DefaultFieldComparator.INSTANCE.areEqual(true, true), 'Equal Booleans should compare equal');
	}

	/**
	 * @description Verifies isFieldDirty() throws when the field argument is null.
	 */
	@IsTest
	static void shouldThrowWhenIsFieldDirtyReceivesNullField() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		Boolean threw = false;
		// Act
		try {
			tracked.isFieldDirty(null);
		} catch (TrackedRecordException e) {
			threw = true;
		}
		// Assert
		Assert.isTrue(threw, 'isFieldDirty(null) should throw TrackedRecordException');
	}

	/**
	 * @description Verifies getOriginal() throws when the field argument is null.
	 */
	@IsTest
	static void shouldThrowWhenGetOriginalReceivesNullField() {
		// Arrange
		TrackedRecord tracked = TrackedRecord.wrap(buildAccount(1, 'Acme'));
		Boolean threw = false;
		// Act
		try {
			tracked.getOriginal(null);
		} catch (TrackedRecordException e) {
			threw = true;
		}
		// Assert
		Assert.isTrue(threw, 'getOriginal(null) should throw TrackedRecordException');
	}

	// ── Test helpers ──────────────────────────────────────────────

	/**
	 * @description Builds a syntactically valid Salesforce Id for the given
	 * SObject type by combining the type's key prefix with a zero-padded
	 * counter. Used to avoid hardcoded Id literals (PMD AvoidHardcodingId).
	 * @param sObjectType The SObject type whose key prefix should be used.
	 * @param counter A unique number used to generate distinct Ids.
	 * @return A syntactically valid Id for the given SObject type.
	 */
	private static Id fakeId(SObjectType sObjectType, Integer counter) {
		String prefix = sObjectType.getDescribe().getKeyPrefix();
		String body = String.valueOf(counter).leftPad(12, '0');
		return Id.valueOf(prefix + body);
	}

	/**
	 * @description Builds an Account in memory with a synthetic Id and the
	 * given name. Avoids DML and reuses the fakeId helper.
	 * @param counter Unique number used to seed the synthetic Id.
	 * @param name The Account Name to set.
	 * @return A new Account populated with the given values.
	 */
	private static Account buildAccount(Integer counter, String name) {
		return new Account(Id = fakeId(Account.SObjectType, counter), Name = name);
	}

	/**
	 * @description Test-only IFieldComparator that compares strings without
	 * regard to case, used to verify withComparator() integration.
	 */
	private class CaseInsensitiveComparator implements IFieldComparator {
		/**
		 * @description Compares two values, treating String values as equal
		 * when they match case-insensitively. Falls back to default for non-Strings.
		 * @param a First value.
		 * @param b Second value.
		 * @return True if values are equal under case-insensitive String rules.
		 */
		public Boolean areEqual(Object a, Object b) {
			if (a instanceof String && b instanceof String) {
				return ((String) a).equalsIgnoreCase((String) b);
			}
			return DefaultFieldComparator.INSTANCE.areEqual(a, b);
		}
	}
}
