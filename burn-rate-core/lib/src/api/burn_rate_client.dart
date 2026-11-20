import 'transactions_client.dart';
import 'categories_client.dart';
import 'api_http.dart';

import 'package:http/http.dart' as http;

class BurnRateClient {
  BurnRateClient(Uri baseUrl, {http.Client? httpClient})
    : _http = ApiHttp(baseUrl, httpClient: httpClient) {
    categories = CategoriesClient(_http);
    transactions = TransactionsClient(_http);
  }

  final ApiHttp _http;
  late final CategoriesClient categories;
  late final TransactionsClient transactions;

  void close() => _http.close();
}
