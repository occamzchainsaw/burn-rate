import '../models/transaction.dart';

import 'api_http.dart';

import 'package:burn_rate_shared/burn_rate_shared.dart';

class TransactionsClient {
  TransactionsClient(this._http);

  final ApiHttp _http;
  static const String _path = '/api/v1/transactions';

  Future<List<Transaction>> list({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
    String? categoryId,
  }) async {
    final json = await _http.send(
      'GET',
      _path,
      query: {
        if (from != null) 'from': formatDate(from),
        if (to != null) 'to': formatDate(to),
        'type': ?type?.name,
        'categoryId': ?categoryId,
      },
    );
    return (json as List)
        .map((item) => Transaction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Transaction> getById(String id) async {
    final json = await _http.send('GET', '$_path/$id');
    return Transaction.fromJson(json as Map<String, dynamic>);
  }

  Future<Transaction> create(TransactionDraft draft) async {
    final json = await _http.send('POST', _path, body: draft.toJson());
    return Transaction.fromJson(json as Map<String, dynamic>);
  }

  Future<Transaction> replace(String id, TransactionDraft draft) async {
    final json = await _http.send('PUT', '$_path/$id', body: draft.toJson());
    return Transaction.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _http.send('DELETE', '$_path/$id');
  }
}
