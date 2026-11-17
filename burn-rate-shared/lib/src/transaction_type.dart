enum TransactionType {
  expense,
  income;

  static TransactionType parse(Object? value) {
    for (final t in TransactionType.values) {
      if (t.name == value) return t;
    }
    final allowed = TransactionType.values.map((t) => t.name).join(', ');
    throw FormatException("'type' must be one of: $allowed");
  }
}
