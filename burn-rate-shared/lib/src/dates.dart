/// Parses date from YYYY-MM-DD. [field] is only for the error message
DateTime parseDate(Object? value, String field) {
  final error = FormatException(
    "'$field' must be a valid date in YYYY-MM-DD format",
  );
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw error;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || formatDate(parsed) != value) throw error;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
