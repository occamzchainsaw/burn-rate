import 'package:burn_rate_shared/burn_rate_shared.dart';

class TransactionDraft {
  const TransactionDraft({
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

  Map<String, Object?> toJson() => {
    'type': type.name,
    'amount': amount,
    'currency': currency,
    'categoryId': categoryId,
    'date': formatDate(date),
    'note': note,
  };
}

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.categoryId,
    required this.date,
    this.note,
  });

  final String id;
  final TransactionType type;
  final int amount;
  final String currency;
  final String categoryId;
  final DateTime date;
  final String? note;

  factory Transaction.fromJson(Map<String, Object?> json) => Transaction(
    id: json['id'] as String,
    type: TransactionType.parse(json['type']),
    amount: json['amount'] as int,
    currency: json['currency'] as String,
    categoryId: json['categoryId'] as String,
    date: parseDate(json['date'], 'date'),
    note: json['note'] as String?,
  );
}
