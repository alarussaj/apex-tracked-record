/**
 * @description Strategy interface for comparing two field values for equality.
 * Used by TrackedRecord.setIfChanged() to decide whether a new value differs
 * from the current value.
 *
 * Implementations should be stateless and side-effect-free.
 *
 * @group TrackedRecord
 * @see https://github.com/alarussaj/apex-tracked-record
 */
public interface IFieldComparator {
	/**
	 * @description Returns true if a and b should be treated as equal.
	 * @param a First value, typically the original field value.
	 * @param b Second value, typically the proposed new value.
	 * @return True if equal under the implementation's rules.
	 */
	Boolean areEqual(Object a, Object b);
}
