/**
 * @description Test-only IFieldComparator that compares strings without
 * regard to case, used to verify TrackedRecord.withComparator() integration.
 */
@IsTest
public class CaseInsensitiveComparator implements IFieldComparator {
	public Boolean areEqual(Object a, Object b) {
		if (a instanceof String && b instanceof String) {
			return ((String) a).equalsIgnoreCase((String) b);
		}
		return DefaultFieldComparator.INSTANCE.areEqual(a, b);
	}
}
