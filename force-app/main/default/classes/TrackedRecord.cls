/**
 * @description Tracks field-level changes against an original SObject record
 * for safe, narrow DML updates. Wraps a queried record, captures explicit
 * set() calls, and produces a DML-ready SObject containing only the Id and
 * the fields that actually changed.
 *
 * Update-only by design. Use plain SObject construction for inserts.
 *
 * @group TrackedRecord
 * @see https://github.com/alarussaj/apex-tracked-record
 */
public inherited sharing class TrackedRecord {
	private final SObject original;
	private final Map<SObjectField, Object> changes = new Map<SObjectField, Object>();
	private IFieldComparator comparator = DefaultFieldComparator.INSTANCE;

	/**
	 * @description Wraps a single existing record for change tracking.
	 * @param record A queried SObject. Must not be null and must have a non-null Id.
	 * @return A new TrackedRecord wrapping the supplied record.
	 * @throws TrackedRecordException if record is null or record.Id is null.
	 */
	public static TrackedRecord wrap(SObject record) {
		return new TrackedRecord(record);
	}

	/**
	 * @description Wraps a list of existing records. Order is preserved.
	 * @param records List of queried SObjects.
	 * @return List of TrackedRecord, one per input record.
	 * @throws TrackedRecordException if records is null or any element fails wrap() validation.
	 */
	public static List<TrackedRecord> wrapAll(List<SObject> records) {
		if (records == null) {
			throw new TrackedRecordException('records must not be null.');
		}
		List<TrackedRecord> result = new List<TrackedRecord>();
		for (SObject record : records) {
			result.add(wrap(record));
		}
		return result;
	}

	/**
	 * @description Private constructor enforcing that all instances are
	 * created via the wrap() factory methods. Validates that the record
	 * exists and has an Id.
	 * @param record A queried SObject. Must not be null and must have a non-null Id.
	 * @throws TrackedRecordException if record is null or record.Id is null.
	 */
	private TrackedRecord(SObject record) {
		if (record == null) {
			throw new TrackedRecordException('record must not be null.');
		}
		if (record.Id == null) {
			throw new TrackedRecordException(
				'record.Id must not be null. TrackedRecord is for existing ' +
				'records. Use plain SObject construction for inserts.'
			);
		}
		this.original = record;
	}

	/**
	 * @description Tracks a field as changed. Always records the change
	 * regardless of whether the new value equals the current value.
	 * @param field SObjectField to mark as changed.
	 * @param value New value for the field. May be null.
	 * @return This TrackedRecord, for chaining.
	 * @throws TrackedRecordException if field is null.
	 */
	public TrackedRecord set(SObjectField field, Object value) {
		validateField(field);
		changes.put(field, value);
		return this;
	}

	/**
	 * @description Tracks a field as changed only if the new value differs
	 * from the original (pre-change) value. Comparison is delegated to the
	 * configured IFieldComparator.
	 * @param field SObjectField to evaluate.
	 * @param value Proposed new value.
	 * @return This TrackedRecord, for chaining.
	 * @throws TrackedRecordException if field is null.
	 */
	public TrackedRecord setIfChanged(SObjectField field, Object value) {
		validateField(field);
		Object originalValue = original.get(field);
		if (!comparator.areEqual(originalValue, value)) {
			changes.put(field, value);
		}
		return this;
	}

	/**
	 * @description Removes a previously-tracked change for a single field.
	 * No-op if the field was not dirty.
	 * @param field SObjectField to clear from the change set.
	 * @return This TrackedRecord, for chaining.
	 * @throws TrackedRecordException if field is null.
	 */
	public TrackedRecord clear(SObjectField field) {
		validateField(field);
		changes.remove(field);
		return this;
	}

	/**
	 * @description Removes all tracked changes, returning the wrapper to its
	 * initial state.
	 * @return This TrackedRecord, for chaining.
	 */
	public TrackedRecord reset() {
		changes.clear();
		return this;
	}

	/**
	 * @description Returns the original wrapped SObject. The canonical pattern
	 * is to cast the result to the concrete SObject type for typed field reads.
	 * @return The original SObject as wrapped, never null.
	 */
	public SObject getRecord() {
		return original;
	}

	/**
	 * @description Returns the original (pre-change) value of a single field,
	 * regardless of any tracked changes.
	 * @param field SObjectField whose original value is requested.
	 * @return The value as it appears on the original record.
	 * @throws TrackedRecordException if field is null.
	 */
	public Object getOriginal(SObjectField field) {
		validateField(field);
		return original.get(field);
	}

	/**
	 * @description Returns true if at least one field has been tracked as changed.
	 * @return True when any change has been recorded.
	 */
	public Boolean isDirty() {
		return !changes.isEmpty();
	}

	/**
	 * @description Returns true if the specified field has been tracked as changed.
	 * @param field SObjectField to check.
	 * @return True when the field is currently dirty.
	 * @throws TrackedRecordException if field is null.
	 */
	public Boolean isFieldDirty(SObjectField field) {
		validateField(field);
		return changes.containsKey(field);
	}

	/**
	 * @description Returns a defensive copy of the set of dirty fields.
	 * @return Set of SObjectField currently tracked as changed.
	 */
	public Set<SObjectField> getDirtyFields() {
		return changes.keySet().clone();
	}

	/**
	 * @description Returns the dirty fields as a List, suitable for APIs that
	 * expect List<SObjectField> (e.g., fflib registerDirty(SObject, List<SObjectField>)).
	 * @return List of SObjectField currently tracked as changed.
	 */
	public List<SObjectField> getDirtyFieldList() {
		return new List<SObjectField>(changes.keySet());
	}

	/**
	 * @description Returns a defensive copy of the dirty field-to-value map.
	 * Useful for higher-level frameworks that need to introspect changes
	 * without reconstructing them from toDmlRecord().
	 * @return Map of SObjectField to the tracked new value.
	 */
	public Map<SObjectField, Object> getChangedValues() {
		return new Map<SObjectField, Object>(changes);
	}

	/**
	 * @description Produces a fresh SObject of the same type as the original,
	 * populated with the original Id and only the dirty fields. Pass directly
	 * to DML or any Unit of Work that accepts an SObject.
	 * @return SObject with Id and dirty fields only.
	 */
	public SObject toDmlRecord() {
		SObject dmlRecord = original.getSObjectType().newSObject(original.Id);
		for (SObjectField field : changes.keySet()) {
			dmlRecord.put(field, changes.get(field));
		}
		return dmlRecord;
	}

	/**
	 * @description Returns DML records for every dirty TrackedRecord in the
	 * input list. Calls toDmlRecord() once per dirty record. Non-dirty records
	 * and null elements are filtered out. Null input returns an empty list.
	 * @param tracked List of TrackedRecord to convert.
	 * @return List of SObject ready for bulk DML.
	 */
	public static List<SObject> toDmlRecords(List<TrackedRecord> tracked) {
		if (tracked == null) return new List<SObject>();
		List<SObject> result = new List<SObject>();
		for (TrackedRecord trackedRecord : tracked) {
			if (trackedRecord != null && trackedRecord.isDirty()) {
				result.add(trackedRecord.toDmlRecord());
			}
		}
		return result;
	}

	/**
	 * @description Replaces the comparator used by setIfChanged().
	 * Passing null resets to DefaultFieldComparator.INSTANCE.
	 * @param comparator The IFieldComparator to apply, or null to restore default.
	 * @return This TrackedRecord, for chaining.
	 */
	public TrackedRecord withComparator(IFieldComparator comparator) {
		this.comparator = (comparator == null) ? DefaultFieldComparator.INSTANCE : comparator;
		return this;
	}

	/**
	 * @description Validates that an SObjectField argument is not null,
	 * throwing TrackedRecordException if it is. Used by every public
	 * method that accepts an SObjectField parameter.
	 * @param field SObjectField to validate.
	 * @throws TrackedRecordException if field is null.
	 */
	private void validateField(SObjectField field) {
		if (field == null) throw new TrackedRecordException('field must not be null.');
	}
}
