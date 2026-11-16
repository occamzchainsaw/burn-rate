import 'dart:io';

import 'package:burn_rate_api/burn_rate_api.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main(List<String> args) async {
  final transactionsRepo = InMemoryTransactionRepository();
  final categoriesRepo = InMemoryCategoryRepository();
  final handler = buildHandler(transactionsRepo, categoriesRepo);
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('Listening on http://${server.address.address}:${server.port}');
}
