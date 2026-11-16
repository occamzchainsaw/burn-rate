import 'package:uuid/uuid.dart';

import '../models/transaction.dart';
import 'transaction_repository.dart';

class InMemoryTransactionRepository implements TransactionRepository {
  final _items = <String, Transaction>{};
  final _uuid = Uuid();

  @override
  Future<Transaction> create(TransactionInput input) async {
    final t = Transaction.fromInput(_uuid.v4(), input);
    _items[t.id] = t;
    return t;
  }

  @override
  Future<bool> delete(String id) async => _items.remove(id) != null;

  @override
  Future<Transaction?> getById(String id) async => _items[id];

  @override
  Future<List<Transaction>> list({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
  }) async {
    return _items.values
        .where(
          (t) =>
              (from == null || !t.date.isBefore(from)) &&
              (to == null || !t.date.isAfter(to)) &&
              (type == null || t.type == type),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<Transaction?> replace(String id, TransactionInput input) async {
    if (!_items.containsKey(id)) return null;
    final t = Transaction.fromInput(id, input);
    _items[id] = t;
    return t;
  }
}
