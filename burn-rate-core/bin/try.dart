import 'dart:convert';

import 'package:burn_rate_core/src/api/burn_rate_client.dart';
import 'package:burn_rate_core/src/models/api_exception.dart';
import 'package:burn_rate_core/src/models/category.dart';
import 'package:burn_rate_core/src/models/transaction.dart';
import 'package:burn_rate_shared/burn_rate_shared.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final client = BurnRateClient(Uri.parse('http://localhost:8080'));

    try {
      final groceries = await client.categories.create(
        const CategoryDraft(name: 'Groceries', type: TransactionType.expense),
      );
      print('created category: ${groceries.id} ${groceries.name}');

      final t1 = await client.transactions.create(TransactionDraft(
        type: TransactionType.expense,
        amount: 4599,
        currency: 'PLN',
        categoryId: groceries.id,
        date: DateTime(2026, 11, 18),
        note: 'Biedronka',
      ));
      final t2 = await client.transactions.create(TransactionDraft(
        type: TransactionType.expense,
        amount: 1250,
        currency: 'PLN',
        categoryId: groceries.id,
        date: DateTime(2026, 11, 20),
      ));
      print('created transactions: ${t1.id}, ${t2.id}');

      final fetched = await client.categories.getById(groceries.id);
      print('get category: ${fetched.name} (${fetched.type.name})');

      final fetchedTx = await client.transactions.getById(t1.id);
      print('get transaction: ${fetchedTx.amount} ${fetchedTx.currency} ${formatDate(fetchedTx.date)} ${fetchedTx.note}');

      print('all transactions in category:');
      for (final t in await client.transactions.list(categoryId: groceries.id)) {
        print('  ${formatDate(t.date)}  ${t.amount}  ${t.note ?? '-'}');
      }

      print('from 2026-11-19:');
      for (final t in await client.transactions.list(from: DateTime(2026, 11, 19))) {
        print('  ${formatDate(t.date)}  ${t.amount}');
      }
    } on ApiConnectionException catch (e) {
      print('connection failed: ${e.message}');
    } on ApiException catch (e) {
      print('server error ${e.statusCode}: ${e.message}');
    } finally {
      client.close();
    }
}
