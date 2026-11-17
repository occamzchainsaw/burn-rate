import 'categories_client.dart';
import 'api_http.dart';

import 'package:http/http.dart' as http;

class BurnRateClient {
  BurnRateClient(Uri baseUrl, {http.Client? httpClient})
    : _http = ApiHttp(baseUrl, httpClient: httpClient) {
    categories = CategoriesClient(_http);
  }

  final ApiHttp _http;
  late final CategoriesClient categories;

  void close() => _http.close();
}
