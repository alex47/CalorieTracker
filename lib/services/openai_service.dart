import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

class OpenAIService {
  OpenAIService(this.apiKey);

  static const int maxAttempts = 3;
  static const Duration requestTimeout = Duration(seconds: 20);

  final String apiKey;

  static const String systemPrompt = '''
You are a nutrition estimation assistant.
Return ONLY JSON with this schema:
{ "items": [ { "name": "", "amount": "", "calories": 0, "fat": 0, "protein": 0, "carbs": 0, "notes": "" } ], "error": "" }
Rules:
- Parse each food and its amount from the user text.
- If units are unclear, make a reasonable assumption and note it in "notes".
- Calories must be per item.
- Express calories in kilocalories (kcal).
- Include fat, protein, and carbs (grams) per item.
- Correct obvious typos in food names and amounts.
- Normalize food names to proper capitalization (e.g. "yogurt" -> "Yogurt").
- Normalize amount text to clean, readable formatting.
- Keep "amount" short and simple:
  - Use metric units in output (g, kg, ml, l) whenever applicable.
  - If user input uses non-metric units (cup, tablespoon, ounce, pound, etc.), convert to a reasonable metric amount.
  - Prefer concise forms like "200 g", "250 ml", "1 slice (30 g)".
  - Avoid long phrases or explanations in "amount".
- On successful parse, keep "notes" informational only; do not ask follow-up questions or request user actions.
- If you cannot extract at least one valid food name + amount pair, return:
  { "items": [], "error": "<a short natural-language explanation of what is missing and what the user should clarify>" }
- The "error" text must sound natural and helpful, not templated.
- Do not add any extra text outside JSON.
''';

  Future<void> testConnection({required String model}) async {
    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/responses'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'input': 'Reply with OK.',
            'store': false,
            'max_output_tokens': 16,
          }),
        )
        .timeout(requestTimeout, onTimeout: () {
          throw StateError('OpenAI request timed out.');
        });

    if (response.statusCode >= 400) {
      throw StateError('OpenAI request failed: ${response.statusCode} ${response.body}');
    }
  }

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
            ? '$userInput\n\nReminder: respond ONLY with valid JSON, include calories/fat/protein/carbs, and use metric units for amounts.'
            : userInput,
      },
    ];

    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/responses'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'input': messages,
            'store': false,
          }),
        )
        .timeout(requestTimeout, onTimeout: () {
          throw StateError('OpenAI request timed out.');
        });

    if (response.statusCode >= 400) {
      throw StateError('OpenAI request failed: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _parseResponse(Map<String, dynamic> response) {
    final content = _extractResponseText(response);
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
      final fat = map['fat'];
      final protein = map['protein'];
      final carbs = map['carbs'];
      if (name.trim().isEmpty || amount.trim().isEmpty) {
        throw const FormatException('Missing name or amount.');
      }
      if (calories is! num || calories <= 0) {
        throw const FormatException('Missing or invalid calories.');
      }
      if (fat is! num || fat < 0) {
        throw const FormatException('Missing or invalid fat.');
      }
      if (protein is! num || protein < 0) {
        throw const FormatException('Missing or invalid protein.');
      }
      if (carbs is! num || carbs < 0) {
        throw const FormatException('Missing or invalid carbs.');
      }
    }

    return parsed;
  }

  String? _extractResponseText(Map<String, dynamic> response) {
    final direct = response['output_text'] as String?;
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final output = response['output'] as List<dynamic>?;
    if (output == null || output.isEmpty) {
      return null;
    }

    for (final item in output) {
      final map = item as Map<String, dynamic>;
      final content = map['content'] as List<dynamic>?;
      if (content == null) {
        continue;
      }
      for (final part in content) {
        final contentPart = part as Map<String, dynamic>;
        final text = contentPart['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    }
    return null;
  }
}
