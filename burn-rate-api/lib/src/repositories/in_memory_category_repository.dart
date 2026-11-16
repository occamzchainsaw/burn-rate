import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import 'category_repository.dart';

class InMemoryCategoryRepository implements CategoryRepository {
  final _items = <String, Category>{};
  final _uuid = Uuid();

  @override
  Future<Category> create(CategoryInput input) async {
    final t = Category.fromInput(_uuid.v4(), input);
    _items[t.id] = t;
    return t;
  }

  @override
  Future<bool> delete(String id) async => _items.remove(id) != null;

  @override
  Future<Category?> getById(String id) async => _items[id];

  @override
  Future<List<Category>> list({TransactionType? type}) async {
    return _items.values
        .where(
          (t) => (type == null || t.type == type),
        )
        .toList()
      ..sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
  }

  @override
  Future<Category?> replace(String id, CategoryInput input) async {
    if (!_items.containsKey(id)) return null;
    final t = Category.fromInput(id, input);
    _items[id] = t;
    return t;
  }
}
