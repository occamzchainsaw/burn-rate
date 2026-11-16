import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../errors.dart';

Response jsonResponse(
  Object? body, {
  int status = 200,
  Map<String, String>? headers,
}) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
  );
}

Future<Object?> readJson(Request request) async {
  final body = await request.readAsString();
  if (body.trim().isEmpty) {
    throw const BadRequestException('Request body is empty');
  }
  try {
    return jsonDecode(body);
  } on FormatException catch (e) {
    throw BadRequestException('Malformed JSON: ${e.message}');
  }
}
