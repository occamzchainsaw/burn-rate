import '../models/category.dart';

import 'package:burn_rate_shared/burn_rate_shared.dart';

// Storage abstraction
abstract interface class CategoryRepository {
  Future<List<Category>> list({TransactionType? type});

  Future<Category?> getById(String id);

  Future<Category> create(CategoryInput input);

  Future<Category?> replace(String id, CategoryInput input);

  Future<bool> delete(String id);
}
