import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../errors.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../repositories/category_repository.dart';
import '../repositories/transaction_repository.dart';
import 'json.dart';

class CategoriesApi {
  CategoriesApi(this._categories, this._transactions);

  final CategoryRepository _categories;
  final TransactionRepository _transactions;

  static const _base = '/api/v1/categories';

  void register(Router router) {
    router
      ..get(_base, _list) // GET    /api/v1/categories?from=&to=&type=
      ..post(_base, _create) // POST   /api/v1/categories
      ..get('$_base/<id>', _get) // GET    /api/v1/categories/{id}
      ..put('$_base/<id>', _replace) // PUT    /api/v1/categories/{id}
      ..delete('$_base/<id>', _delete); // DELETE /api/v1/categories/{id}
  }

  Future<Response> _list(Request request) async {
    final q = request.url.queryParameters;
    final items = await _categories.list(
      type: q['type'] == null ? null : TransactionType.parse(q['type']),
    );
    return jsonResponse(items);
  }

  Future<Response> _create(Request request) async {
    final input = CategoryInput.fromJson(await readJson(request));
    final created = await _categories.create(input);
    return jsonResponse(
      created,
      status: 201,
      headers: {'location': '$_base/${created.id}'},
    );
  }

  Future<Response> _get(Request request, String id) async {
    final t = await _categories.getById(id);
    if (t == null) throw NotFoundException('Transaction $id not found');
    return jsonResponse(t);
  }

  Future<Response> _replace(Request request, String id) async {
    final input = CategoryInput.fromJson(await readJson(request));
    final updated = await _categories.replace(id, input);
    if (updated == null) throw NotFoundException('Transaction $id not found');
    return jsonResponse(updated);
  }

  Future<Response> _delete(Request request, String id) async {
    if (await _hasDependentTransactions(id)) return Response(409);
    final deleted = await _categories.delete(id);
    if (!deleted) throw NotFoundException('Transaction $id not found');
    return Response(204); // No Content
  }

  Future<bool> _hasDependentTransactions(String categoryId) async {
    final transactions = await _transactions.list(
      from: null,
      to: null,
      type: null,
    );
    return transactions
        .where((t) => t.categoryId.compareTo(categoryId) == 0)
        .isNotEmpty;
  }
}
