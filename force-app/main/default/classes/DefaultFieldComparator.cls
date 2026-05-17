/**
 * @description Default implementation of IFieldComparator. Handles null-safety,
 * Decimal scale-insensitive comparison, and case-sensitive String comparison.
 * Stateless — use the INSTANCE singleton for normal cases.
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
	 * @description Compares two values for equality with null-safety, Decimal
	 * scale-insensitivity (so 1.0 and 1.00 are treated as equal), and
	 * case-sensitive String comparison.
	 *
	 * Note: Apex's == operator is case-insensitive on Strings, which would
	 * cause 'foo' and 'FOO' to be treated as equal. This implementation uses
	 * String.equals() explicitly to give case-sensitive comparison.
	 * @param a First value.
	 * @param b Second value.
	 * @return True if values are equal under default rules.
	 */
	public Boolean areEqual(Object a, Object b) {
		// prettier-ignore
		if (a == null && b == null) return true;
		// prettier-ignore
		if (a == null || b == null) return false;
		// Decimal: compare by value, ignoring scale (1.0 == 1.00)
		if (a instanceof Decimal && b instanceof Decimal) {
			return ((Decimal) a) - ((Decimal) b) == 0;
		}
		// String: use case-sensitive equality (Apex == is case-insensitive)
		if (a instanceof String && b instanceof String) {
			return ((String) a).equals((String) b);
		}
		return a == b;
	}
}
