/// Returns the value at [name] in [row], asserting that the column exists
/// and is non-null. Throws [FormatException] otherwise. The [table] name is
/// used in the error message to identify which DTO failed to parse.
Object requireColumn(Map<String, Object?> row, String name, String table) {
  if (!row.containsKey(name)) {
    throw FormatException('Missing column "$name" in $table row');
  }
  final value = row[name];
  if (value == null) {
    throw FormatException('Column "$name" must not be NULL in $table row');
  }
  return value;
}
