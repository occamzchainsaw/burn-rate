import '../errors.dart';

enum TransactionType {
  expense,
  income;

  static TransactionType parse(Object? value) {
    for (final t in TransactionType.values) {
      if (t.name == value) return t;
    }
    final allowed = TransactionType.values.map((t) => t.name).join(', ');
    throw BadRequestException("'type' must be one of: $allowed");
  }
}

class TransactionInput {
  const TransactionInput({
    required this.type,
    required this.amount,
    required this.currency,
    required this.categoryId,
    required this.date,
    this.note,
  });

  final TransactionType type;
  final int amount;
  final String currency;
  final String categoryId;
  final DateTime date;
  final String? note;

  factory TransactionInput.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const BadRequestException('Request body must be a JSON object');
    }

    final amount = json['amount'];
    if (amount is! int || amount <= 0) {
      throw const BadRequestException("'amount' must be a positive integer");
    }

    final currency = json['currency'];
    if (currency is! String || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const BadRequestException(
        "'currency' must be a 3-letter ISO 4217 code, e.g. PLN",
      );
    }

    final categoryId = json['categoryId'];
    if (categoryId is! String || categoryId.isEmpty) {
      throw const BadRequestException(
        "'categoryId' must be a non-empty string",
      );
    }

    final note = json['note'];
    if (note != null && note is! String) {
      throw const BadRequestException("'note' must be a string or null");
    }

    return TransactionInput(
      type: TransactionType.parse(json['type']),
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: parseDate(json['date'], 'date'),
      note: note as String?,
    );
  }
}

class Transaction {
  Transaction.fromInput(this.id, TransactionInput input)
    : type = input.type,
      amount = input.amount,
      currency = input.currency,
      categoryId = input.categoryId,
      date = input.date,
      note = input.note;

  final String id;
  final TransactionType type;
  final int amount;
  final String currency;
  final String categoryId;
  final DateTime date;
  final String? note;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'currency': currency,
    'categoryId': categoryId,
    'date': formatDate(date),
    'note': note,
  };
}

DateTime parseDate(Object? value, String field) {
  final error = BadRequestException(
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
