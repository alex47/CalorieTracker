import 'dart:convert';

import 'package:calorie_tracker/services/openai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('initial calorie request includes the current user input once',
      () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _successResponse();
    });
    addTearDown(client.close);

    await _service(client).estimateCalories(
      model: 'test-model',
      languageCode: 'en',
      reasoningEffort: 'low',
      maxOutputTokens: 1000,
      userInput: '100 g apple',
      history: const [],
    );

    final input = _requestInput(requestBody);
    expect(input.map((message) => message['role']), ['system', 'user']);
    expect(
      input.where(
        (message) =>
            message['role'] == 'user' && message['content'] == '100 g apple',
      ),
      hasLength(1),
    );
  });

  test('follow-up calorie request preserves prior turns without duplication',
      () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _successResponse();
    });
    addTearDown(client.close);
    final history = [
      {'role': 'user', 'content': '100 g apple'},
      {'role': 'assistant', 'content': jsonEncode(_estimatePayload())},
    ];

    await _service(client).estimateCalories(
      model: 'test-model',
      languageCode: 'en',
      reasoningEffort: 'low',
      maxOutputTokens: 1000,
      userInput: '200 g banana',
      history: history,
    );

    final input = _requestInput(requestBody);
    expect(
      input.map((message) => message['role']),
      ['system', 'user', 'assistant', 'user'],
    );
    expect(
      input.where((message) => message['content'] == '100 g apple'),
      hasLength(1),
    );
    expect(
      input.where((message) => message['content'] == '200 g banana'),
      hasLength(1),
    );
    expect(history, hasLength(2));
  });
}

OpenAIService _service(http.Client client) {
  return OpenAIService(
    'test-key',
    client: client,
    requestTimeout: const Duration(seconds: 1),
  );
}

List<Map<String, dynamic>> _requestInput(Map<String, dynamic> requestBody) {
  return (requestBody['input'] as List<dynamic>)
      .map((message) => Map<String, dynamic>.from(message as Map))
      .toList();
}

http.Response _successResponse() {
  return http.Response(
    jsonEncode({
      'output': [
        {
          'content': [
            {'text': jsonEncode(_estimatePayload())},
          ],
        },
      ],
    }),
    200,
  );
}

Map<String, dynamic> _estimatePayload() {
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
