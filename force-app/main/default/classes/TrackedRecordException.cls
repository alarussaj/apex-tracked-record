/**
 * @description Thrown when TrackedRecord receives invalid input — null record,
 * null Id on the wrapped record, or null field arguments. These represent
 * programmer errors, not runtime conditions to recover from.
 *
 * @group TrackedRecord
 * @see https://github.com/alarussaj/apex-tracked-record
 */
public class TrackedRecordException extends Exception {
}
