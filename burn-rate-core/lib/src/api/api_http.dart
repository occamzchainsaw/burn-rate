import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api_exception.dart';

class ApiHttp {
  ApiHttp(this._baseUrl, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final Uri _baseUrl;
  final http.Client _http;

  void close() => _http.close();

  Future<Object?> send(
    String method,
    String path, {
    Map<String, String> query = const {},
    Object? body,
  }) async {
    final Uri url = _baseUrl
        .replace(path: path)
        .replace(queryParameters: query);

    final request = http.Request(method, url);
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 10));
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiConnectionException('No response within 10 s');
    } on Exception catch (e) {
      throw ApiConnectionException('Request failed: $e');
    }

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }

    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  String _errorMessage(http.Response response) {
    final fallback = response.reasonPhrase ?? 'HTTP ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> && decoded['error'] is String
          ? decoded['error'] as String
          : fallback;
    } on FormatException {
      return fallback;
    }
  }
}
