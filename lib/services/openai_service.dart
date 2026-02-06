import 'dart:convert';

import 'package:http/http.dart' as http;

class OpenAIService {
  OpenAIService(this.apiKey);

  static const int maxAttempts = 3;

  final String apiKey;

  static const String systemPrompt = '''
You are a nutrition estimation assistant.
Return ONLY JSON with this schema:
{ "items": [ { "name": "", "amount": "", "calories": 0, "notes": "" } ], "error": "" }
Rules:
- Parse each food and its amount from the user text.
- If units are unclear, make a reasonable assumption and note it in "notes".
- Calories must be per item.
- Correct obvious typos in food names and amounts.
- Normalize food names to proper capitalization (e.g. "yogurt" -> "Yogurt").
- Normalize amount text to clean, readable formatting.
- On successful parse, keep "notes" informational only; do not ask follow-up questions or request user actions.
- If you cannot extract at least one valid food name + amount pair, return:
  { "items": [], "error": "<a short natural-language explanation of what is missing and what the user should clarify>" }
- The "error" text must sound natural and helpful, not templated.
- Do not add any extra text outside JSON.
''';

  Future<Map<String, dynamic>> estimateCalories({
    required String model,
    required String userInput,
    required List<Map<String, String>> history,
  }) async {
    var attempt = 0;
    Object? lastError;

    while (attempt < maxAttempts) {
      try {
        final response = await _sendRequest(
          model: model,
          userInput: userInput,
          history: history,
          includeReminder: attempt > 0,
        );
        return _parseResponse(response);
      } catch (error) {
        if (_isNonRetriableRequestError(error)) {
          rethrow;
        }
        lastError = error;
        attempt += 1;
      }
    }

    throw StateError('Failed to parse AI response after $maxAttempts attempts: $lastError');
  }

  bool _isNonRetriableRequestError(Object error) {
    if (error is! StateError) {
      return false;
    }
    final message = error.message.toString();
    return message.contains('OpenAI request failed: 4') ||
        message.startsWith('The AI says:');
  }

  Future<Map<String, dynamic>> _sendRequest({
    required String model,
    required String userInput,
    required List<Map<String, String>> history,
    required bool includeReminder,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {
        'role': 'user',
        'content': includeReminder
            ? '$userInput\n\nReminder: respond ONLY with valid JSON and include calories and units.'
            : userInput,
      },
    ];

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
      }),
    );

    if (response.statusCode >= 400) {
      throw StateError('OpenAI request failed: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _parseResponse(Map<String, dynamic> response) {
    final choices = response['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const FormatException('Missing choices in response.');
    }

    final content = choices.first['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw const FormatException('Empty content in response.');
    }

    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final errorMessage = (parsed['error'] as String?)?.trim();
    if (errorMessage != null && errorMessage.isNotEmpty) {
      throw StateError('The AI says: $errorMessage');
    }

    final items = parsed['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      throw const FormatException('AI returned no items and no explanation.');
    }

    for (final item in items) {
      final map = item as Map<String, dynamic>;
      final name = map['name'] as String? ?? '';
      final amount = map['amount'] as String? ?? '';
      final calories = map['calories'];
      if (name.trim().isEmpty || amount.trim().isEmpty) {
        throw const FormatException('Missing name or amount.');
      }
      if (calories is! num || calories <= 0) {
        throw const FormatException('Missing or invalid calories.');
      }
    }

    return parsed;
  }
}
