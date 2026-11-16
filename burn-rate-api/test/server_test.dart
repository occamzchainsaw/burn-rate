import 'dart:convert';
import 'dart:io';

import 'package:burn_rate_api/burn_rate_api.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  group('bin/server.dart entrypoint', () {
    late Process process;
    late String baseUrl;

    setUp(() async {
      process = await Process.start(
        'dart',
        ['run', 'bin/server.dart'],
        environment: {'PORT': '0'},
      );

      final line = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first;
      final match = RegExp(r'Listening on http://[^:]+:(\d+)').firstMatch(line);
      if (match == null) {
        fail('Unexpected server startup output: $line');
      }
      baseUrl = 'http://127.0.0.1:${match.group(1)}';
    });

    tearDown(() async {
      process.kill();
      await process.exitCode;
    });

    test('responds on /health and returns 404 for unknown routes', () async {
      final health = await http.get(Uri.parse('$baseUrl/health'));
      expect(health.statusCode, 200);
      expect(health.body, 'ok');

      final missing = await http.get(Uri.parse('$baseUrl/foobar'));
      expect(missing.statusCode, 404);
      expect(jsonDecode(missing.body), {'error': 'No route for GET /foobar'});
    });
  });

  group('Burn Rate API', () {
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      final handler = buildHandler(
        InMemoryTransactionRepository(),
        InMemoryCategoryRepository(),
        logging: false,
      );
      server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    Uri uri(String path, [Map<String, String>? query]) =>
        Uri.parse('$baseUrl$path').replace(queryParameters: query);

    Future<http.Response> postJson(String path, Object? body) => http.post(
      uri(path),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );

    Future<http.Response> putJson(String path, Object? body) => http.put(
      uri(path),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );

    Future<Map<String, dynamic>> createCategory({
      required String name,
      String type = 'expense',
    }) async {
      final res = await postJson('/api/v1/categories', {
        'name': name,
        'type': type,
      });
      expect(res.statusCode, 201, reason: res.body);
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    Future<Map<String, dynamic>> createTransaction({
      required String categoryId,
      String type = 'expense',
      int amount = 2500,
      String currency = 'PLN',
      String date = '2026-11-16',
      String? note,
    }) async {
      final payload = <String, Object?>{
        'type': type,
        'amount': amount,
        'currency': currency,
        'categoryId': categoryId,
        'date': date,
        'note': ?note,
      };
      final res = await postJson('/api/v1/transactions', payload);
      expect(res.statusCode, 201, reason: res.body);
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    Map<String, dynamic> decodeError(http.Response res) {
      expect(res.headers['content-type'], startsWith('application/json'));
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    group('health & error handling', () {
      test('GET /health returns 200 ok', () async {
        final res = await http.get(uri('/health'));
        expect(res.statusCode, 200);
        expect(res.body, 'ok');
      });

      test('unknown route returns 404 JSON error', () async {
        final res = await http.post(uri('/api/v1/does-not-exist'));
        expect(res.statusCode, 404);
        expect(decodeError(res), {
          'error': 'No route for POST /api/v1/does-not-exist',
        });
      });

      test('empty body returns 400', () async {
        final res = await http.post(uri('/api/v1/categories'), body: '   ');
        expect(res.statusCode, 400);
        expect(decodeError(res), {'error': 'Request body is empty'});
      });

      test('malformed JSON returns 400', () async {
        final res = await http.post(
          uri('/api/v1/categories'),
          body: '{not valid json',
        );
        expect(res.statusCode, 400);
        expect(decodeError(res)['error'], startsWith('Malformed JSON:'));
      });

      test('non-object JSON body returns 400', () async {
        final catRes = await postJson('/api/v1/categories', ['Groceries']);
        expect(catRes.statusCode, 400);
        expect(decodeError(catRes), {
          'error': 'Request body must be a JSON object',
        });

        final txRes = await postJson('/api/v1/transactions', 123);
        expect(txRes.statusCode, 400);
        expect(decodeError(txRes), {
          'error': 'Request body must be a JSON object',
        });
      });
    });

    group('categories', () {
      test('GET /api/v1/categories returns empty list initially', () async {
        final res = await http.get(uri('/api/v1/categories'));
        expect(res.statusCode, 200);
        expect(res.headers['content-type'], startsWith('application/json'));
        expect(jsonDecode(res.body), isEmpty);
      });

      test('POST /api/v1/categories creates category and trims name', () async {
        final res = await postJson('/api/v1/categories', {
          'name': '  Groceries  ',
          'type': 'expense',
        });

        expect(res.statusCode, 201);
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        expect(
          body['id'],
          isA<String>().having((s) => s.isNotEmpty, 'non-empty', isTrue),
        );
        expect(body['name'], 'Groceries');
        expect(body['type'], 'expense');
        expect(res.headers['location'], '/api/v1/categories/${body['id']}');
      });

      test('POST /api/v1/categories accepts name up to 50 chars', () async {
        final fiftyChars = 'a' * 50;
        final created = await createCategory(name: '  $fiftyChars  ');
        expect(created['name'], fiftyChars);
      });

      test('POST /api/v1/categories validates name and type', () async {
        final invalidPayloads = <Map<String, Object?>>[
          {'type': 'expense'},
          {'name': 123, 'type': 'expense'},
          {'name': '   ', 'type': 'expense'},
          {'name': 'a' * 51, 'type': 'expense'},
          {'name': 'Salary'},
          {'name': 'Salary', 'type': 'transfer'},
        ];

        for (final payload in invalidPayloads) {
          final res = await postJson('/api/v1/categories', payload);
          expect(res.statusCode, 400, reason: 'Payload: $payload');
          expect(decodeError(res)['error'], isA<String>());
        }
      });

      test(
        'GET /api/v1/categories filters by type and rejects invalid type',
        () async {
          final food = await createCategory(name: 'Food', type: 'expense');
          final rent = await createCategory(name: 'Rent', type: 'expense');
          final salary = await createCategory(name: 'Salary', type: 'income');

          final allRes = await http.get(uri('/api/v1/categories'));
          expect(allRes.statusCode, 200);
          final all = jsonDecode(allRes.body) as List<dynamic>;
          expect(
            all.map((c) => c['id']),
            unorderedEquals([food['id'], rent['id'], salary['id']]),
          );

          final expRes = await http.get(
            uri('/api/v1/categories', {'type': 'expense'}),
          );
          expect(expRes.statusCode, 200);
          final expenses = jsonDecode(expRes.body) as List<dynamic>;
          expect(
            expenses.map((c) => c['id']),
            unorderedEquals([food['id'], rent['id']]),
          );

          final incRes = await http.get(
            uri('/api/v1/categories', {'type': 'income'}),
          );
          expect(incRes.statusCode, 200);
          final incomes = jsonDecode(incRes.body) as List<dynamic>;
          expect(incomes.map((c) => c['id']), [salary['id']]);

          final badRes = await http.get(
            uri('/api/v1/categories', {'type': 'bogus'}),
          );
          expect(badRes.statusCode, 400);
        },
      );

      test('GET /api/v1/categories/{id} returns category or 404', () async {
        final created = await createCategory(name: 'Coffee');

        final found = await http.get(
          uri('/api/v1/categories/${created['id']}'),
        );
        expect(found.statusCode, 200);
        expect(jsonDecode(found.body), created);

        final missing = await http.get(uri('/api/v1/categories/missing-id'));
        expect(missing.statusCode, 404);
      });

      test(
        'PUT /api/v1/categories/{id} updates category when no conflict',
        () async {
          final created = await createCategory(name: 'Misc', type: 'expense');

          final updatedRes = await putJson(
            '/api/v1/categories/${created['id']}',
            {'name': 'Bonus', 'type': 'income'},
          );
          expect(updatedRes.statusCode, 200);
          expect(jsonDecode(updatedRes.body), {
            'id': created['id'],
            'name': 'Bonus',
            'type': 'income',
          });

          final missingRes = await putJson('/api/v1/categories/missing-id', {
            'name': 'Other',
            'type': 'expense',
          });
          expect(missingRes.statusCode, 404);
        },
      );

      test('PUT /api/v1/categories/{id} allows rename with transactions, rejects type change with 409', () async {
        final cat = await createCategory(name: 'Food', type: 'expense');
        await createTransaction(
          categoryId: cat['id'] as String,
          type: 'expense',
        );

        final renameRes = await putJson('/api/v1/categories/${cat['id']}', {
          'name': 'Dining Out',
          'type': 'expense',
        });
        expect(renameRes.statusCode, 200);
        expect(jsonDecode(renameRes.body)['name'], 'Dining Out');

        final conflictRes = await putJson('/api/v1/categories/${cat['id']}', {
          'name': 'Dining Out',
          'type': 'income',
        });
        expect(conflictRes.statusCode, 409);
        expect(
          decodeError(conflictRes)['error'],
          contains("Can't change type"),
        );

        final after = await http.get(uri('/api/v1/categories/${cat['id']}'));
        expect(after.statusCode, 200);
        expect(jsonDecode(after.body)['type'], 'expense');
      });

      test(
        'DELETE /api/v1/categories/{id} deletes unused category or returns 404',
        () async {
          final cat = await createCategory(name: 'Temporary');

          final del = await http.delete(uri('/api/v1/categories/${cat['id']}'));
          expect(del.statusCode, 204);
          expect(del.body, isEmpty);

          final getAfter = await http.get(
            uri('/api/v1/categories/${cat['id']}'),
          );
          expect(getAfter.statusCode, 404);

          final delMissing = await http.delete(
            uri('/api/v1/categories/${cat['id']}'),
          );
          expect(delMissing.statusCode, 404);
        },
      );

      test('DELETE /api/v1/categories/{id} returns 409 when transactions exist, succeeds after they are deleted', () async {
        final cat = await createCategory(name: 'Utilities');
        final tx = await createTransaction(categoryId: cat['id'] as String);

        final conflictDel = await http.delete(
          uri('/api/v1/categories/${cat['id']}'),
        );
        expect(conflictDel.statusCode, 409);
        expect(decodeError(conflictDel)['error'], contains('still exist'));

        final stillThere = await http.get(
          uri('/api/v1/categories/${cat['id']}'),
        );
        expect(stillThere.statusCode, 200);

        final delTx = await http.delete(
          uri('/api/v1/transactions/${tx['id']}'),
        );
        expect(delTx.statusCode, 204);

        final okDel = await http.delete(uri('/api/v1/categories/${cat['id']}'));
        expect(okDel.statusCode, 204);
      });
    });

    group('transactions', () {
      test('GET /api/v1/transactions returns empty list initially', () async {
        final res = await http.get(uri('/api/v1/transactions'));
        expect(res.statusCode, 200);
        expect(jsonDecode(res.body), isEmpty);
      });

      test(
        'POST /api/v1/transactions creates transactions with and without note',
        () async {
          final cat = await createCategory(name: 'Groceries', type: 'expense');

          final withNote = await postJson('/api/v1/transactions', {
            'type': 'expense',
            'amount': 4250,
            'currency': 'PLN',
            'categoryId': cat['id'],
            'date': '2026-11-10',
            'note': 'Weekly shop',
          });
          expect(withNote.statusCode, 201);
          final body1 = jsonDecode(withNote.body) as Map<String, dynamic>;
          expect(
            withNote.headers['location'],
            '/api/v1/transactions/${body1['id']}',
          );
          expect(body1, {
            'id': body1['id'],
            'type': 'expense',
            'amount': 4250,
            'currency': 'PLN',
            'categoryId': cat['id'],
            'date': '2026-11-10',
            'note': 'Weekly shop',
          });

          final withoutNote = await postJson('/api/v1/transactions', {
            'type': 'expense',
            'amount': 100,
            'currency': 'EUR',
            'categoryId': cat['id'],
            'date': '2026-11-11',
          });
          expect(withoutNote.statusCode, 201);
          final body2 = jsonDecode(withoutNote.body) as Map<String, dynamic>;
          expect(body2['note'], isNull);
        },
      );

      test(
        'POST /api/v1/transactions validates fields and category constraints',
        () async {
          final expenseCat = await createCategory(
            name: 'Food',
            type: 'expense',
          );
          final incomeCat = await createCategory(
            name: 'Salary',
            type: 'income',
          );

          final valid = <String, Object?>{
            'type': 'expense',
            'amount': 1000,
            'currency': 'PLN',
            'categoryId': expenseCat['id'],
            'date': '2026-11-16',
          };

          final invalidPayloads = <Map<String, Object?>>[
            {...valid, 'type': 'invalid'},
            {...valid, 'amount': 0},
            {...valid, 'amount': -50},
            {...valid, 'amount': 12.34},
            {...valid, 'amount': '100'},
            {...valid, 'currency': 'pln'},
            {...valid, 'currency': 'PL'},
            {...valid, 'currency': 'PLNN'},
            {...valid, 'categoryId': ''},
            {...valid, 'categoryId': 123},
            {...valid, 'date': '16-11-2026'},
            {...valid, 'date': '2026-02-30'},
            {...valid, 'date': '2026-13-01'},
            {...valid, 'note': 42},
            {...valid, 'categoryId': 'non-existent-id'},
            {...valid, 'categoryId': incomeCat['id']},
          ];

          for (final payload in invalidPayloads) {
            final res = await postJson('/api/v1/transactions', payload);
            expect(
              res.statusCode,
              400,
              reason: 'Payload: $payload, body: ${res.body}',
            );
            expect(decodeError(res)['error'], isA<String>());
          }
        },
      );

      test(
        'GET /api/v1/transactions sorts by date and supports filters',
        () async {
          final food = await createCategory(name: 'Food', type: 'expense');
          final rent = await createCategory(name: 'Rent', type: 'expense');
          final salary = await createCategory(name: 'Salary', type: 'income');

          final t3 = await createTransaction(
            categoryId: food['id'] as String,
            type: 'expense',
            date: '2026-11-20',
            amount: 300,
          );
          final t1 = await createTransaction(
            categoryId: salary['id'] as String,
            type: 'income',
            date: '2026-11-01',
            amount: 500000,
          );
          final t2 = await createTransaction(
            categoryId: rent['id'] as String,
            type: 'expense',
            date: '2026-11-10',
            amount: 200000,
          );

          final allRes = await http.get(uri('/api/v1/transactions'));
          expect(allRes.statusCode, 200);
          final all = jsonDecode(allRes.body) as List<dynamic>;
          expect(all.map((t) => t['id']), [t1['id'], t2['id'], t3['id']]);

          final rangeRes = await http.get(
            uri('/api/v1/transactions', {
              'from': '2026-11-01',
              'to': '2026-11-10',
            }),
          );
          expect(rangeRes.statusCode, 200);
          expect(
            (jsonDecode(rangeRes.body) as List<dynamic>).map((t) => t['id']),
            [t1['id'], t2['id']],
          );

          final typeRes = await http.get(
            uri('/api/v1/transactions', {'type': 'expense'}),
          );
          expect(typeRes.statusCode, 200);
          expect(
            (jsonDecode(typeRes.body) as List<dynamic>).map((t) => t['id']),
            [t2['id'], t3['id']],
          );

          final catRes = await http.get(
            uri('/api/v1/transactions', {'categoryId': food['id'] as String}),
          );
          expect(catRes.statusCode, 200);
          expect(
            (jsonDecode(catRes.body) as List<dynamic>).map((t) => t['id']),
            [t3['id']],
          );

          final combinedRes = await http.get(
            uri('/api/v1/transactions', {
              'from': '2026-11-05',
              'to': '2026-11-25',
              'type': 'expense',
              'categoryId': rent['id'] as String,
            }),
          );
          expect(combinedRes.statusCode, 200);
          expect(
            (jsonDecode(combinedRes.body) as List<dynamic>).map((t) => t['id']),
            [t2['id']],
          );
        },
      );

      test(
        'GET /api/v1/transactions rejects invalid query params with 400',
        () async {
          for (final query in [
            {'from': '2026-02-30'},
            {'to': 'not-a-date'},
            {'type': 'other'},
          ]) {
            final res = await http.get(uri('/api/v1/transactions', query));
            expect(res.statusCode, 400, reason: 'Query: $query');
          }
        },
      );

      test(
        'GET /api/v1/transactions/{id} returns transaction or 404',
        () async {
          final cat = await createCategory(name: 'Books');
          final tx = await createTransaction(categoryId: cat['id'] as String);

          final found = await http.get(uri('/api/v1/transactions/${tx['id']}'));
          expect(found.statusCode, 200);
          expect(jsonDecode(found.body), tx);

          final missing = await http.get(
            uri('/api/v1/transactions/missing-id'),
          );
          expect(missing.statusCode, 404);
        },
      );

      test('PUT /api/v1/transactions/{id} replaces transaction, validates, or returns 404', () async {
        final expCat = await createCategory(name: 'Coffee', type: 'expense');
        final incCat = await createCategory(name: 'Refund', type: 'income');
        final tx = await createTransaction(
          categoryId: expCat['id'] as String,
          type: 'expense',
          amount: 1500,
          note: 'Latte',
        );

        final updated = await putJson('/api/v1/transactions/${tx['id']}', {
          'type': 'income',
          'amount': 1500,
          'currency': 'USD',
          'categoryId': incCat['id'],
          'date': '2026-11-17',
          'note': null,
        });
        expect(updated.statusCode, 200);
        expect(jsonDecode(updated.body), {
          'id': tx['id'],
          'type': 'income',
          'amount': 1500,
          'currency': 'USD',
          'categoryId': incCat['id'],
          'date': '2026-11-17',
          'note': null,
        });

        final mismatched = await putJson('/api/v1/transactions/${tx['id']}', {
          'type': 'expense',
          'amount': 1500,
          'currency': 'USD',
          'categoryId': incCat['id'],
          'date': '2026-11-17',
        });
        expect(mismatched.statusCode, 400);

        final missing = await putJson('/api/v1/transactions/missing-id', {
          'type': 'expense',
          'amount': 1500,
          'currency': 'USD',
          'categoryId': expCat['id'],
          'date': '2026-11-17',
        });
        expect(missing.statusCode, 404);
      });

      test(
        'DELETE /api/v1/transactions/{id} deletes transaction or returns 404',
        () async {
          final cat = await createCategory(name: 'Travel');
          final tx = await createTransaction(categoryId: cat['id'] as String);

          final del = await http.delete(
            uri('/api/v1/transactions/${tx['id']}'),
          );
          expect(del.statusCode, 204);
          expect(del.body, isEmpty);

          final getAfter = await http.get(
            uri('/api/v1/transactions/${tx['id']}'),
          );
          expect(getAfter.statusCode, 404);

          final delMissing = await http.delete(
            uri('/api/v1/transactions/${tx['id']}'),
          );
          expect(delMissing.statusCode, 404);
        },
      );
    });
  });
}
