import 'dart:async';
import 'dart:convert';

import 'package:calorie_tracker/models/app_defaults.dart';
import 'package:calorie_tracker/services/openai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/http_fixture.dart';

void main() {
  group('OpenAI estimate requests', () {
    test('sends headers, schema, settings, localization, and history',
        () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          readFixture('openai/estimate_success.json'),
          200,
        );
      });
      addTearDown(client.close);
      final history = [
        {'role': 'user', 'content': '100 g alma'},
        {'role': 'assistant', 'content': '{"synthetic":true}'},
      ];

      final result = await _service(client).estimateCalories(
        model: 'synthetic-model',
        languageCode: 'hu',
        reasoningEffort: 'invalid-effort',
        maxOutputTokens: 1,
        userInput: '200 g alma',
        history: history,
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      final input = (body['input'] as List).cast<Map<String, dynamic>>();
      expect(captured.url.path, '/v1/responses');
      expect(captured.headers['Authorization'], 'Bearer dummy-key');
      expect(captured.headers['Content-Type'], 'application/json');
      expect(body['model'], 'synthetic-model');
      expect(body['store'], isFalse);
      expect(body['max_output_tokens'], AppDefaults.maxOutputTokens);
      expect(body['reasoning'], {'effort': AppDefaults.reasoningEffort});
      expect(
        ((body['text'] as Map)['format'] as Map)['schema'],
        OpenAIService.estimateSchema,
      );
      expect(input.map((message) => message['role']), [
        'system',
        'user',
        'assistant',
        'user',
      ]);
      expect(input.first['content'], contains('Hungarian'));
      expect(history, hasLength(2));
      expect(result['items'], hasLength(1));
      final item = (result['items'] as List).single as Map<String, dynamic>;
      expect(item['calories'], 104);
      expect(item['fat'], closeTo(0.4, 0.0001));
      expect(item['protein'], closeTo(0.6, 0.0001));
      expect(item['carbs'], 28);
    });

    for (final shape in ['nested', 'top-level', 'direct', 'string-part']) {
      test('extracts response content from the $shape shape', () async {
        final payload = _validEstimatePayload();
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode(_responseShape(shape, jsonEncode(payload))),
            200,
          ),
        );
        addTearDown(client.close);

        final result = await _estimate(_service(client));

        expect(result['items'], hasLength(1));
      });
    }

    test('uses each user turn once and adds retry reminders only on retries',
        () async {
      final bodies = <Map<String, dynamic>>[];
      var calls = 0;
      final client = MockClient((request) async {
        calls += 1;
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (calls < 3) {
          return http.Response(_nestedTextResponse('{'), 200);
        }
        return http.Response(
          _nestedTextResponse(jsonEncode(_validEstimatePayload())),
          200,
        );
      });
      addTearDown(client.close);

      await _estimate(_service(client), userInput: '100 g apple');

      expect(calls, 3);
      final firstInput = (bodies.first['input'] as List).cast<Map>();
      final retryInput = (bodies[1]['input'] as List).cast<Map>();
      expect(
        firstInput.where((message) => message['content'] == '100 g apple'),
        hasLength(1),
      );
      expect(firstInput.last['content'], isNot(contains('Reminder:')));
      expect(retryInput.last['content'], contains('Reminder:'));
    });
  });

  group('OpenAI estimate parsing and retries', () {
    test('invalid outer JSON retries and preserves the raw body', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls += 1;
        return http.Response('outer-$calls', 200);
      });
      addTearDown(client.close);

      await expectLater(
        _estimate(_service(client)),
        throwsA(
          isA<AiParseException>().having(
            (error) => error.rawResponseText,
            'rawResponseText',
            'outer-3',
          ),
        ),
      );
      expect(calls, OpenAIService.maxAttempts);
    });

    test('invalid content JSON retains the most useful final content',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls += 1;
        return http.Response(_nestedTextResponse('content-$calls'), 200);
      });
      addTearDown(client.close);

      await expectLater(
        _estimate(_service(client)),
        throwsA(
          isA<AiParseException>().having(
            (error) => error.rawResponseText,
            'rawResponseText',
            'content-3',
          ),
        ),
      );
    });

    test('missing content retries to the configured limit', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls += 1;
        return http.Response(jsonEncode({'output': []}), 200);
      });
      addTearDown(client.close);

      await expectLater(
        _estimate(_service(client)),
        throwsA(isA<AiParseException>()),
      );
      expect(calls, OpenAIService.maxAttempts);
    });

    for (final scenario in [
      (name: 'empty items', key: 'items', value: <dynamic>[]),
      (name: 'missing name', key: 'name', value: ''),
      (name: 'missing amount', key: 'amount', value: ''),
      (name: 'invalid unit', key: 'standard_unit', value: ''),
      (name: 'invalid unit amount', key: 'standard_unit_amount', value: 0),
      (name: 'invalid multiplier', key: 'multiplier', value: 0),
      (name: 'invalid calories', key: 'standard_calories', value: 0),
      (name: 'invalid fat', key: 'standard_fat', value: -1),
      (name: 'invalid protein', key: 'standard_protein', value: -1),
      (name: 'invalid carbs', key: 'standard_carbs', value: -1),
    ]) {
      test('rejects ${scenario.name}', () async {
        final payload = _validEstimatePayload();
        if (scenario.key == 'items') {
          payload['items'] = scenario.value;
        } else {
          final item =
              (payload['items'] as List).single as Map<String, dynamic>;
          item[scenario.key] = scenario.value;
        }
        var calls = 0;
        final client = MockClient((_) async {
          calls += 1;
          return http.Response(
            _nestedTextResponse(jsonEncode(payload)),
            200,
          );
        });
        addTearDown(client.close);

        await expectLater(
          _estimate(_service(client)),
          throwsA(isA<AiParseException>()),
        );
        expect(calls, OpenAIService.maxAttempts);
      });
    }

    test('AI-provided errors are non-retriable', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls += 1;
        return http.Response(
          _nestedTextResponse(
            jsonEncode({'items': [], 'error': 'Add an amount.'}),
          ),
          200,
        );
      });
      addTearDown(client.close);

      await expectLater(
        _estimate(_service(client)),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            '${OpenAIService.aiSaysErrorPrefix}Add an amount.',
          ),
        ),
      );
      expect(calls, 1);
    });

    for (final scenario in [
      (status: 400, expectedCalls: 1),
      (status: 429, expectedCalls: OpenAIService.maxAttempts),
      (status: 500, expectedCalls: OpenAIService.maxAttempts),
    ]) {
      test('HTTP ${scenario.status} uses the intended retry policy', () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls += 1;
          return http.Response('synthetic HTTP failure', scenario.status);
        });
        addTearDown(client.close);

        await expectLater(
          _estimate(_service(client)),
          throwsA(anyOf(isA<StateError>(), isA<AiParseException>())),
        );
        expect(calls, scenario.expectedCalls);
      });
    }

    test('timeouts retry without live network access or real delays', () async {
      var calls = 0;
      final client = MockClient((_) {
        calls += 1;
        return Completer<http.Response>().future;
      });
      addTearDown(client.close);

      await expectLater(
        _estimate(
          OpenAIService(
            'dummy-key',
            client: client,
            requestTimeout: Duration.zero,
          ),
        ),
        throwsA(isA<AiParseException>()),
      );
      expect(calls, OpenAIService.maxAttempts);
    });
  });

  group('OpenAI day summaries', () {
    test('sends the schema and parses empty issues and suggestions', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          readFixture('openai/day_summary_success.json'),
          200,
        );
      });
      addTearDown(client.close);
      final snapshot = {
        'date': '2026-07-19',
        'nutrition_objective': null,
        'objective_adherence': null,
      };

      final summary = await _service(client).summarizeDay(
        model: 'summary-model',
        languageCode: 'hu',
        reasoningEffort: 'high',
        maxOutputTokens: 700,
        daySnapshot: snapshot,
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      final input = (body['input'] as List).cast<Map<String, dynamic>>();
      expect(body['model'], 'summary-model');
      expect(body['reasoning'], {'effort': 'high'});
      expect(body['max_output_tokens'], 700);
      expect(
        ((body['text'] as Map)['format'] as Map)['schema'],
        OpenAIService.daySummarySchema,
      );
      expect(input.first['content'], contains('Hungarian'));
      expect(input.last['content'], contains(jsonEncode(snapshot)));
      expect(summary.summary, 'A balanced synthetic day.');
      expect(summary.issues, isEmpty);
      expect(summary.suggestions, isEmpty);
    });

    test('rejects invalid outer JSON, invalid content, and missing content',
        () async {
      for (final body in [
        '{',
        _nestedTextResponse('{'),
        jsonEncode({'output': []}),
      ]) {
        final client = MockClient((_) async => http.Response(body, 200));
        addTearDown(client.close);

        await expectLater(
          _service(client).summarizeDay(
            model: 'summary-model',
            languageCode: 'en',
            reasoningEffort: 'low',
            maxOutputTokens: 700,
            daySnapshot: const {},
          ),
          throwsA(isA<AiParseException>()),
        );
      }
    });

    test('rejects summaries without summary text', () async {
      final client = MockClient(
        (_) async => http.Response(
          _nestedTextResponse(
            jsonEncode({
              'summary': '',
              'highlights': [],
              'issues': [],
              'suggestions': [],
            }),
          ),
          200,
        ),
      );
      addTearDown(client.close);

      await expectLater(
        _service(client).summarizeDay(
          model: 'summary-model',
          languageCode: 'en',
          reasoningEffort: 'low',
          maxOutputTokens: 700,
          daySnapshot: const {},
        ),
        throwsA(isA<AiParseException>()),
      );
    });
  });

  group('OpenAI model and connection operations', () {
    test('fetches, sorts, and deduplicates every returned model ID', () async {
      final client = MockClient(
        (_) async => http.Response(
          readFixture('openai/models_success.json'),
          200,
        ),
      );
      addTearDown(client.close);

      final models = await _service(client).fetchAvailableModels();

      expect(models, [
        'newer-model',
        'same-date-a',
        'same-date-b',
        'older-model',
      ]);
    });

    test('rejects empty model responses and model HTTP failures', () async {
      final emptyClient = MockClient(
        (_) async => http.Response(jsonEncode({'data': []}), 200),
      );
      addTearDown(emptyClient.close);
      await expectLater(
        _service(emptyClient).fetchAvailableModels(),
        throwsStateError,
      );

      final errorClient = MockClient(
        (_) async => http.Response('synthetic failure', 401),
      );
      addTearDown(errorClient.close);
      await expectLater(
        _service(errorClient).fetchAvailableModels(),
        throwsStateError,
      );
    });

    test('connection test sends the minimal request and accepts success',
        () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);

      await _service(client).testConnection(model: 'connection-model');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body, {
        'model': 'connection-model',
        'input': 'Reply with OK.',
        'store': false,
        'max_output_tokens': AppDefaults.minOutputTokens,
      });
    });

    test('connection test reports HTTP failures and timeouts', () async {
      final errorClient = MockClient(
        (_) async => http.Response('synthetic failure', 500),
      );
      addTearDown(errorClient.close);
      await expectLater(
        _service(errorClient).testConnection(model: 'test'),
        throwsStateError,
      );

      final timeoutClient =
          MockClient((_) => Completer<http.Response>().future);
      addTearDown(timeoutClient.close);
      await expectLater(
        OpenAIService(
          'dummy-key',
          client: timeoutClient,
          requestTimeout: Duration.zero,
        ).testConnection(model: 'test'),
        throwsStateError,
      );
    });
  });
}

OpenAIService _service(http.Client client) {
  return OpenAIService(
    'dummy-key',
    client: client,
    requestTimeout: const Duration(seconds: 1),
  );
}

Future<Map<String, dynamic>> _estimate(
  OpenAIService service, {
  String userInput = '100 g apple',
}) {
  return service.estimateCalories(
    model: 'test-model',
    languageCode: 'en',
    reasoningEffort: 'low',
    maxOutputTokens: 1000,
    userInput: userInput,
    history: const [],
  );
}

Map<String, dynamic> _validEstimatePayload() {
  return {
    'items': [
      {
        'name': 'Apple',
        'amount': '100 g',
        'standard_unit': 'g',
        'standard_unit_amount': 100,
        'multiplier': 100,
        'standard_calories': 52,
        'standard_fat': 0.2,
        'standard_protein': 0.3,
        'standard_carbs': 14,
        'notes': '',
      },
    ],
    'error': '',
  };
}

Map<String, dynamic> _responseShape(String shape, String text) {
  return switch (shape) {
    'top-level' => {'output_text': text},
    'direct' => {
        'output': [
          {'text': text},
        ],
      },
    'string-part' => {
        'output': [
          {
            'content': [text],
          },
        ],
      },
    _ => {
        'output': [
          {
            'content': [
              {'type': 'output_text', 'text': text},
            ],
          },
        ],
      },
  };
}

String _nestedTextResponse(String text) {
  return jsonEncode(_responseShape('nested', text));
}
