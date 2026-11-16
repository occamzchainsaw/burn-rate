import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'json.dart';
import 'middleware.dart';
import 'transactions_api.dart';
import 'categories_api.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/category_repository.dart';

Handler buildHandler(
  TransactionRepository transactions,
  CategoryRepository categories, {
  bool logging = true,
}) {
  final router = Router(
    notFoundHandler: (Request r) => jsonResponse({
      'error': 'No route for ${r.method} /${r.url}',
    }, status: 404),
  );

  router.get('/health', (Request _) => Response.ok('ok'));
  TransactionsApi(transactions, categories).register(router);
  CategoriesApi(categories, transactions).register(router);

  var pipeline = const Pipeline();
  if (logging) pipeline = pipeline.addMiddleware(logRequests());
  return pipeline.addMiddleware(errorHandler()).addHandler(router.call);
}
