import '../models/transaction.dart';

// Storage abstraction
abstract interface class TransactionRepository {
  Future<List<Transaction>> list({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
  });

  Future<Transaction?> getById(String id);

  Future<Transaction> create(TransactionInput input);

  /// Returns null if [id] doesn't exist
  Future<Transaction?> replace(String id, TransactionInput input);

  /// Returns false if [id] doesn't exist
  Future<bool> delete(String id);
}
