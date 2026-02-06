import 'dart:convert';

import 'package:http/http.dart' as http;

class OpenAIService {
  OpenAIService(this.apiKey);

  static const int maxAttempts = 3;

  final String apiKey;

  static const String systemPrompt = '''
You are a nutrition estimation assistant.
Return ONLY JSON with this schema:
{ "items": [ { "name": "", "amount": "", "calories": 0, "notes": "" } ] }
Rules:
- Parse each food and its amount from the user text.
- If units are unclear, make a reasonable assumption and note it in "notes".
- Calories must be per item.
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
        lastError = error;
        attempt += 1;
      }
    }

    throw StateError('Failed to parse AI response after $maxAttempts attempts: $lastError');
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
        'temperature': 0.2,
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
    final items = parsed['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      throw const FormatException('Missing items in response.');
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
