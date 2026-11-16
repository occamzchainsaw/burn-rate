import 'dart:io';

import 'package:shelf/shelf.dart';

import '../errors.dart';
import 'json.dart';

Middleware errorHandler() {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } on ApiException catch (e) {
        return jsonResponse({'error': e.message}, status: e.statusCode);
      } catch (e, stack) {
        stderr.writeln(
          'Unhandled error on ${request.method} ${request.requestedUri}\n$e\n$stack',
        );
        return jsonResponse({'error': 'Internal Server Error'}, status: 500);
      }
    };
  };
}
