/**
 * @description Default implementation of IFieldComparator. Handles null-safety
 * and Decimal scale-insensitive comparison. Stateless — use the INSTANCE
 * singleton for normal cases.
 *
 * @group TrackedRecord
 * @see https://github.com/alarussaj/apex-tracked-record
 */
public inherited sharing class DefaultFieldComparator implements IFieldComparator {
	/**
	 * @description Singleton instance for shared use.
	 */
	public static final DefaultFieldComparator INSTANCE = new DefaultFieldComparator();

	/**
	 * @description Compares two values for equality with null-safety and
	 * Decimal scale-insensitivity (so 1.0 and 1.00 are treated as equal).
	 * @param a First value.
	 * @param b Second value.
	 * @return True if values are equal under default rules.
	 */
	public Boolean areEqual(Object a, Object b) {
		if (a == null && b == null)
			return true;
		if (a == null || b == null)
			return false;
		// Decimal: compare by value, ignoring scale (1.0 == 1.00)
		if (a instanceof Decimal && b instanceof Decimal) {
			return ((Decimal) a) - ((Decimal) b) == 0;
		}
		return a == b;
	}
}
