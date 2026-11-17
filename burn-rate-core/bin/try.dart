import 'dart:convert';

import 'package:burn_rate_core/src/api/burn_rate_client.dart';
import 'package:burn_rate_core/src/models/category.dart';
import 'package:burn_rate_shared/burn_rate_shared.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // final baseUri = Uri.parse('http://localhost:8080/api/v1/categories');

  // final created = await http.post(
  //   baseUri,
  //   headers: {'content-type': 'application/json'},
  //   body: jsonEncode(
  //     const CategoryDraft(
  //       name: 'Groceries',
  //       type: TransactionType.expense,
  //     ).toJson(),
  //   ),
  // );

  // print('POST ${created.statusCode}');
  // print(Category.fromJson(jsonDecode(created.body) as Map<String, dynamic>).id);

  // final listed = await http.get(
  //   baseUri.replace(queryParameters: {'type': 'expense'}),
  // );
  // final categories = (jsonDecode(listed.body) as List)
  //     .map((item) => Category.fromJson(item as Map<String, dynamic>))
  //     .toList();
  // for (final c in categories) {
  //   print('${c.id}  [${c.type.name}]  ${c.name}');
  // }

  final client = BurnRateClient(Uri.parse('http://localhost:8080'));
  final created = await client.categories.create(
    const CategoryDraft(name: 'Groceries', type: TransactionType.expense),
  );
  print('Created  ${created.id} [${created.type.name}] ${created.name}');
  var categories = await client.categories.list(type: TransactionType.expense);
  print('Initial list');
  for (final c in categories) {
    print('${c.id} [${c.type.name}] ${c.name}');
  }
  final replaced = await client.categories.replace(
    created.id,
    const CategoryDraft(name: 'Petrol', type: TransactionType.expense),
  );
  print('Replaced ${replaced.id} [${replaced.type.name}] ${replaced.name}');
  categories = await client.categories.list(type: TransactionType.expense);
  print('Final list');
  for (final c in categories) {
    print('${c.id} [${c.type.name}] ${c.name}');
  }
}
