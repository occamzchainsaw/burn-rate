import 'dart:async';

import 'package:burn_rate_shared/burn_rate_shared.dart';

import 'api_http.dart';
import '../models/category.dart';

class CategoriesClient {
  CategoriesClient(this._http);

  final ApiHttp _http;
  static const String _path = '/api/v1/categories';

  Future<List<Category>> list({TransactionType? type}) async {
    final json = await _http.send('GET', _path, query: {'type': ?type?.name});
    return (json as List)
        .map((item) => Category.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Category> getById(String id) async {
    final json = await _http.send('GET', '$_path/$id');
    return Category.fromJson(json as Map<String, dynamic>);
  }

  Future<Category> create(CategoryDraft draft) async {
    final json = await _http.send('POST', _path, body: draft.toJson());
    return Category.fromJson(json as Map<String, dynamic>);
  }

  Future<Category> replace(String id, CategoryDraft draft) async {
    final json = await _http.send('PUT', '$_path/$id', body: draft.toJson());
    return Category.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _http.send('DELETE', '$_path/$id');
  }
}
