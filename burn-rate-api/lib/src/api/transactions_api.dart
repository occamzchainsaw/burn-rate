import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:burn_rate_shared/burn_rate_shared.dart';

import '../errors.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/category_repository.dart';
import 'json.dart';

class TransactionsApi {
  TransactionsApi(this._transactions, this._categories);

  final TransactionRepository _transactions;
  final CategoryRepository _categories;

  static const _base = '/api/v1/transactions';

  void register(Router router) {
    router
      ..get(_base, _list) // GET    /api/v1/transactions?from=&to=&type=
      ..post(_base, _create) // POST   /api/v1/transactions
      ..get('$_base/<id>', _get) // GET    /api/v1/transactions/{id}
      ..put('$_base/<id>', _replace) // PUT    /api/v1/transactions/{id}
      ..delete('$_base/<id>', _delete); // DELETE /api/v1/transactions/{id}
  }

  Future<Response> _list(Request request) async {
    final q = request.url.queryParameters;
    final items = await _transactions.list(
      from: q['from'] == null ? null : parseDate(q['from'], 'from'),
      to: q['to'] == null ? null : parseDate(q['to'], 'to'),
      type: q['type'] == null ? null : TransactionType.parse(q['type']),
      categoryId: q['categoryId'] == null ? null : q['categoryId'] as String
    );
    return jsonResponse(items);
  }

  Future<Response> _create(Request request) async {
    final input = TransactionInput.fromJson(await readJson(request));
    await _checkCategory(input);
    final created = await _transactions.create(input);
    return jsonResponse(
      created,
      status: 201,
      headers: {'location': '$_base/${created.id}'},
    );
  }

  Future<Response> _get(Request request, String id) async {
    final t = await _transactions.getById(id);
    if (t == null) throw NotFoundException('Transaction $id not found');
    return jsonResponse(t);
  }

  Future<Response> _replace(Request request, String id) async {
    final input = TransactionInput.fromJson(await readJson(request));
    await _checkCategory(input);
    final updated = await _transactions.replace(id, input);
    if (updated == null) throw NotFoundException('Transaction $id not found');
    return jsonResponse(updated);
  }

  Future<Response> _delete(Request request, String id) async {
    final deleted = await _transactions.delete(id);
    if (!deleted) throw NotFoundException('Transaction $id not found');
    return Response(204); // No Content
  }

  Future<void> _checkCategory(TransactionInput input) async {
    final category = await _categories.getById(input.categoryId);
    if (category == null) {
      throw BadRequestException(
        "Category '${input.categoryId}' does not exist",
      );
    }
    if (category.type != input.type) {
      throw BadRequestException(
        "Category '${category.name}' is for ${category.type.name}, not ${input.type.name}",
      );
    }
  }
}
