import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/app_defaults.dart';

class AiParseException implements Exception {
  const AiParseException(
    this.message, {
    this.rawResponseText,
  });

  final String message;
  final String? rawResponseText;

  @override
  String toString() => message;
}

class OpenAIService {
  OpenAIService(
    this.apiKey, {
    Duration? requestTimeout,
  }) : requestTimeout = requestTimeout ?? AppDefaults.openAiRequestTimeout;

  static const int maxAttempts = AppDefaults.openAiMaxAttempts;
  static const int defaultEstimateMaxOutputTokens = AppDefaults.maxOutputTokens;
  static const List<String> reasoningEffortOptions = AppDefaults.reasoningEffortOptions;

  final String apiKey;
  final Duration requestTimeout;

  static const Map<String, dynamic> estimateSchema = {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'name': {'type': 'string'},
            'amount': {'type': 'string'},
            'calories': {'type': 'number'},
            'fat': {'type': 'number'},
            'protein': {'type': 'number'},
            'carbs': {'type': 'number'},
            'notes': {'type': 'string'},
          },
          'required': ['name', 'amount', 'calories', 'fat', 'protein', 'carbs', 'notes'],
        },
      },
      'error': {'type': 'string'},
    },
    'required': ['items', 'error'],
  };

  static const String systemPrompt = '''
You are a nutrition estimation assistant.
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
            'max_output_tokens': AppDefaults.minOutputTokens,
          }),
        )
        .timeout(requestTimeout, onTimeout: () {
          throw StateError('OpenAI request timed out.');
        });

    if (response.statusCode >= 400) {
      throw StateError('OpenAI request failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<List<String>> fetchAvailableModels() async {
    final response = await http
        .get(
          Uri.parse('https://api.openai.com/v1/models'),
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
        )
        .timeout(requestTimeout, onTimeout: () {
          throw StateError('OpenAI request timed out.');
        });

    if (response.statusCode >= 400) {
      throw StateError('OpenAI request failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? const [];
    final ids = data
        .map((item) => item as Map<String, dynamic>)
        .map((item) => item['id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    ids.sort();

    if (ids.isEmpty) {
      throw StateError('No models were returned for this API key.');
    }

    return ids;
  }

  Future<Map<String, dynamic>> estimateCalories({
    required String model,
    required String languageCode,
    required String reasoningEffort,
    required int maxOutputTokens,
    required String userInput,
    required List<Map<String, String>> history,
  }) async {
    var attempt = 0;
    Object? lastError;
    AiParseException? lastParseError;

    while (attempt < maxAttempts) {
      try {
        final response = await _sendRequest(
          model: model,
          languageCode: languageCode,
          reasoningEffort: reasoningEffort,
          maxOutputTokens: maxOutputTokens,
          userInput: userInput,
          history: history,
          includeReminder: attempt > 0,
        );
        return _parseResponse(response);
      } catch (error) {
        if (_isNonRetriableRequestError(error)) {
          rethrow;
        }
        if (error is AiParseException) {
          lastParseError = error;
        }
        lastError = error;
        attempt += 1;
      }
    }

    if (lastParseError != null) {
      throw AiParseException(
        'Failed to parse AI response after $maxAttempts attempts: ${lastParseError.message}',
        rawResponseText: lastParseError.rawResponseText,
      );
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
    required String languageCode,
    required String reasoningEffort,
    required int maxOutputTokens,
    required String userInput,
    required List<Map<String, String>> history,
    required bool includeReminder,
  }) async {
    final effort = reasoningEffortOptions.contains(reasoningEffort)
        ? reasoningEffort
        : AppDefaults.reasoningEffort;
    final outputTokens = maxOutputTokens < AppDefaults.minOutputTokens
        ? defaultEstimateMaxOutputTokens
        : maxOutputTokens;
    final languageName = _languageNameEnglish(languageCode);
    final localizedSystemPrompt =
        '$systemPrompt\n- Write all natural-language output fields ("notes" and "error") in $languageName.';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': localizedSystemPrompt},
      ...history,
      {
        'role': 'user',
        'content': includeReminder
            ? '$userInput\n\nReminder: include calories/fat/protein/carbs and use metric units for amounts.'
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
            'max_output_tokens': outputTokens,
            'reasoning': {'effort': effort},
            'text': {
              'format': {
                'type': 'json_schema',
                'name': 'calorie_estimate',
                'strict': true,
                'schema': estimateSchema,
              },
            },
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

  String _languageNameEnglish(String languageCode) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == languageCode) {
        return lookupAppLocalizations(locale).languageNameEnglish;
      }
    }
    return lookupAppLocalizations(const Locale('en')).languageNameEnglish;
  }

  Map<String, dynamic> _parseResponse(Map<String, dynamic> response) {
    final content = _extractResponseText(response);
    if (content == null || content.isEmpty) {
      throw const AiParseException('Empty content in response.');
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw AiParseException(
        'Failed to parse AI response.',
        rawResponseText: content,
      );
    }
    final errorMessage = (parsed['error'] as String?)?.trim();
    if (errorMessage != null && errorMessage.isNotEmpty) {
      throw StateError('The AI says: $errorMessage');
    }

    final items = parsed['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      throw AiParseException(
        'AI returned no items and no explanation.',
        rawResponseText: content,
      );
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
        throw AiParseException(
          'Missing name or amount.',
          rawResponseText: content,
        );
      }
      if (calories is! num || calories <= 0) {
        throw AiParseException(
          'Missing or invalid calories.',
          rawResponseText: content,
        );
      }
      if (fat is! num || fat < 0) {
        throw AiParseException(
          'Missing or invalid fat.',
          rawResponseText: content,
        );
      }
      if (protein is! num || protein < 0) {
        throw AiParseException(
          'Missing or invalid protein.',
          rawResponseText: content,
        );
      }
      if (carbs is! num || carbs < 0) {
        throw AiParseException(
          'Missing or invalid carbs.',
          rawResponseText: content,
        );
      }
    }

    return parsed;
  }

  String? _extractResponseText(Map<String, dynamic> response) {
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
