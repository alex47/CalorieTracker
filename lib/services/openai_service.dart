import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/app_defaults.dart';
import '../models/day_summary.dart';
import '../models/food_item.dart';

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
    http.Client? client,
  }) : requestTimeout = requestTimeout ?? AppDefaults.openAiRequestTimeout,
        _client = client;

  static const int maxAttempts = AppDefaults.openAiMaxAttempts;
  static const int defaultEstimateMaxOutputTokens = AppDefaults.maxOutputTokens;
  static const List<String> reasoningEffortOptions =
      AppDefaults.reasoningEffortOptions;

  final String apiKey;
  final Duration requestTimeout;
  final http.Client? _client;
  static const String aiSaysErrorPrefix = '__AI_SAYS__:';

  Future<http.Response> _get(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _client?.get(url, headers: headers) ??
        http.get(url, headers: headers);
  }

  Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _client?.post(url, headers: headers, body: body) ??
        http.post(url, headers: headers, body: body);
  }

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
            'standard_unit': {'type': 'string'},
            'standard_unit_amount': {'type': 'number'},
            'multiplier': {'type': 'number'},
            'standard_calories': {'type': 'number'},
            'standard_fat': {'type': 'number'},
            'standard_protein': {'type': 'number'},
            'standard_carbs': {'type': 'number'},
            'notes': {'type': 'string'},
          },
          'required': [
            'name',
            'amount',
            'standard_unit',
            'standard_unit_amount',
            'multiplier',
            'standard_calories',
            'standard_fat',
            'standard_protein',
            'standard_carbs',
            'notes',
          ],
        },
      },
      'error': {'type': 'string'},
    },
    'required': ['items', 'error'],
  };

  static const Map<String, dynamic> daySummarySchema = {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'summary': {'type': 'string'},
      'highlights': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'issues': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'suggestions': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['summary', 'highlights', 'issues', 'suggestions'],
  };

  static const String systemPrompt = '''
You are a nutrition estimation assistant.
Rules:
- Parse each food and its amount from the user text.
- If units are unclear, make a reasonable assumption and note it in "notes".
- For each item, return nutrition for a standard reference amount only (e.g., 100 g, 100 ml, 1 piece, 1 slice, 1 tbsp, 1 cup), not for the full entered amount.
- Return the reference as two fields:
  - "standard_unit_amount" (number, e.g. 100 or 1)
  - "standard_unit" (string, e.g. "g", "ml", "piece", "slice", "tbsp", "cup")
- Use "multiplier" as the entered quantity in `standard_unit` (example: 230 g => standard_unit="g", standard_unit_amount=100, multiplier=230).
- Express calories in kilocalories (kcal) and macros in grams for the standard amount.
- Correct obvious typos in food names and amounts.
- Normalize food names to proper capitalization (e.g. "yogurt" -> "Yogurt").
- Normalize amount text to clean, readable formatting.
- Keep "amount" short and simple:
  - Use metric units in output (g, kg, ml, l) whenever applicable.
  - If user input uses non-metric units (cup, tablespoon, ounce, pound, etc.), convert to a reasonable metric amount.
  - Prefer concise forms like "200 g", "250 ml", "1 slice (30 g)".
  - Avoid long phrases or explanations in "amount".
- Keep "notes" brief and concise:
  - Prefer one short sentence when possible.
  - Include only key assumptions or clarifications.
  - Do not ask follow-up questions or request user actions.
- "multiplier" must be a positive number.
- If you cannot extract at least one valid food name + amount pair, return:
  { "items": [], "error": "<a short natural-language explanation of what is missing and what the user should clarify>" }
- The "error" text must sound natural and helpful, not templated.
''';

  static const String daySummarySystemPrompt = '''
You are a concise nutrition coach summarizing one day of food intake.
Rules:
- Use only the provided JSON data.
- Treat `maintenance_baseline` as estimated maintenance intake for the current body weight, not automatically as the diet objective.
- Use `nutrition_objective` as the configured calorie objective and macro strategy when it is present.
- For a `below_maintenance` calorie objective, any calorie total strictly below the maintenance baseline satisfies the calorie-direction criterion for weight loss. A total at or above maintenance does not.
- Satisfying the weight-loss calorie-direction criterion does not by itself establish that the intake is nutritionally adequate.
- For a `maintenance` calorie objective, use the provided tolerance and precomputed status in `objective_adherence`.
- Evaluate macro strategy adherence from `objective_adherence.macro_distribution`, which compares calorie-share percentages. Do not call the macro distribution incorrect merely because gram totals are below maintenance-based gram values.
- Evaluate nutritional adequacy separately using the food list, total intake, and absolute macro amounts. An on-target macro distribution does not prove that absolute intake is adequate.
- Follow the precomputed objective status in `objective_adherence`; do not reinterpret a weight-loss deficit as an objective failure.
- If `objective_adherence.has_objective_gap` is true, include at least one objective-related `issues` item and one practical `suggestions` item.
- If no nutrition objective is present, do not infer a calorie or macro goal.
- Identify likely strengths and likely gaps in overall dietary quality and completeness.
- Assess overall nutritional completeness broadly; mention only the most relevant factors for this specific day.
- Do not force specific nutrients or example categories if the provided data does not support them.
- If likely incompleteness is detected, include at least one related `issues` item and one practical `suggestions` item.
- When noting likely daily nutrition gaps, include a practical food-based adjustment and briefly state which gap it addresses and why (for example: vitamins, essential fats, fiber, etc.), without restricting the assessment to these examples.
- Do not state an unmeasured nutrient deficiency as fact. Describe micronutrient, fiber, and essential-fat coverage only as a cautious inference from the listed foods.
- If relevant, mention concrete examples briefly, but keep the assessment high-level and practical.
- Keep output practical and brief.
- Write all output as user-facing coaching text. Do not reference JSON field names, keys, or schema terms.
- Return strict JSON only.
- "summary": 1-2 short sentences.
- "highlights": provide 1-5 short bullets with concrete positives (what went well nutritionally today).
- "issues": provide 0-5 short bullets. Return an empty array when no issue is supported by the data.
- "suggestions": provide 0-5 short action-oriented bullets. Return an empty array when no suggestion is warranted.
- Do not include medical advice or diagnosis.
''';

  Future<void> testConnection({required String model}) async {
    final response = await _post(
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
    ).timeout(requestTimeout, onTimeout: () {
      throw StateError('OpenAI request timed out.');
    });

    if (response.statusCode >= 400) {
      throw StateError(
          'OpenAI request failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<List<String>> fetchAvailableModels() async {
    final response = await _get(
      Uri.parse('https://api.openai.com/v1/models'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    ).timeout(requestTimeout, onTimeout: () {
      throw StateError('OpenAI request timed out.');
    });

    if (response.statusCode >= 400) {
      throw StateError(
          'OpenAI request failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? const [];
    final models = data
        .map((item) => item as Map<String, dynamic>)
        .where((item) => item['id'] is String)
        .toList();
    models.sort((a, b) {
      final createdA = a['created'] is num ? (a['created'] as num).toInt() : 0;
      final createdB = b['created'] is num ? (b['created'] as num).toInt() : 0;
      if (createdA != createdB) {
        return createdB.compareTo(createdA);
      }
      final idA = a['id'] as String;
      final idB = b['id'] as String;
      return idA.compareTo(idB);
    });
    final ids = models.map((item) => item['id'] as String).toSet().toList();

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
        rawResponseText:
            lastParseError.rawResponseText ?? lastError?.toString(),
      );
    }

    throw AiParseException(
      'Failed to parse AI response after $maxAttempts attempts: $lastError',
      rawResponseText: lastError?.toString(),
    );
  }

  String buildDaySummaryPrompt({
    required String languageCode,
    required Map<String, dynamic> daySnapshot,
  }) {
    final nutritionObjective =
        daySnapshot['nutrition_objective'] as Map<String, dynamic>?;
    final objectiveAdherence =
        daySnapshot['objective_adherence'] as Map<String, dynamic>?;
    final macroStrategyName =
        (nutritionObjective?['macro_strategy_name'] as String?)?.trim();
    final calorieObjective =
        (nutritionObjective?['calorie_objective'] as String?)?.trim();
    final hasObjectiveGap =
        objectiveAdherence?['has_objective_gap'] as bool? ?? false;
    final languageName = _languageNameEnglish(languageCode);
    final strategyLine = macroStrategyName == null || macroStrategyName.isEmpty
        ? ''
        : '\n- Selected macro strategy: $macroStrategyName.';
    final objectiveLine = switch (calorieObjective) {
      'below_maintenance' =>
        '\nContext:$strategyLine\n- Calorie objective: consume below the estimated maintenance baseline. Every total strictly below maintenance satisfies this objective\'s calorie-direction criterion.',
      'maintenance' =>
        '\nContext:$strategyLine\n- Calorie objective: remain near the estimated maintenance baseline, using the tolerance in the provided adherence data.',
      _ =>
        '\nContext:\n- No calorie or macro objective is configured. Assess dietary quality without inferring one.',
    };
    final objectiveGapLine = objectiveAdherence == null
        ? ''
        : hasObjectiveGap
            ? '\n- An objective gap is present in the provided adherence data. Address the relevant calorie or macro mismatch in both issues and suggestions.'
            : '\n- The provided adherence data has no objective gap. Do not invent an objective failure, but still assess nutritional completeness.';

    return '$daySummarySystemPrompt$objectiveLine$objectiveGapLine\n- Always output all text fields in $languageName.';
  }

  Future<DaySummary> summarizeDay({
    required String model,
    required String languageCode,
    required String reasoningEffort,
    required int maxOutputTokens,
    required Map<String, dynamic> daySnapshot,
  }) async {
    final effort = reasoningEffortOptions.contains(reasoningEffort)
        ? reasoningEffort
        : AppDefaults.reasoningEffort;
    final outputTokens = maxOutputTokens < AppDefaults.minOutputTokens
        ? defaultEstimateMaxOutputTokens
        : maxOutputTokens;
    final localizedSystemPrompt = buildDaySummaryPrompt(
      languageCode: languageCode,
      daySnapshot: daySnapshot,
    );
    final compactSnapshot = jsonEncode(daySnapshot);
    final response = await _post(
      Uri.parse('https://api.openai.com/v1/responses'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'input': [
          {'role': 'system', 'content': localizedSystemPrompt},
          {
            'role': 'user',
            'content':
                'Summarize this day using the required JSON schema.\n\nDay data JSON:\n$compactSnapshot',
          },
        ],
        'store': false,
        'max_output_tokens': outputTokens,
        'reasoning': {'effort': effort},
        'text': {
          'format': {
            'type': 'json_schema',
            'name': 'day_summary',
            'strict': true,
            'schema': daySummarySchema,
          },
        },
      }),
    ).timeout(requestTimeout, onTimeout: () {
      throw StateError('OpenAI request timed out.');
    });

    if (response.statusCode >= 400) {
      throw StateError(
          'OpenAI request failed: ${response.statusCode} ${response.body}');
    }

    final decodedBody = response.body;
    Map<String, dynamic> parsedBody;
    try {
      parsedBody = jsonDecode(decodedBody) as Map<String, dynamic>;
    } catch (_) {
      throw AiParseException(
        'Failed to parse AI response.',
        rawResponseText: decodedBody,
      );
    }

    final content = _extractResponseText(parsedBody);
    if (content == null || content.isEmpty) {
      throw AiParseException(
        'Empty content in response.',
        rawResponseText: decodedBody,
      );
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw AiParseException(
        'Failed to parse AI response.',
        rawResponseText: content.isNotEmpty ? content : decodedBody,
      );
    }

    final summary = DaySummary.fromMap(parsed);
    if (summary.summary.isEmpty) {
      throw AiParseException(
        'Missing summary text.',
        rawResponseText: content.isNotEmpty ? content : decodedBody,
      );
    }
    return summary;
  }

  bool _isNonRetriableRequestError(Object error) {
    if (error is! StateError) {
      return false;
    }
    final message = error.message.toString();
    if (message.startsWith(aiSaysErrorPrefix)) {
      return true;
    }
    if (message.contains('OpenAI request failed: 429')) {
      return false;
    }
    return message.contains('OpenAI request failed: 4');
  }

  Future<_OpenAiResponsePayload> _sendRequest({
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
        '$systemPrompt\n- Always output "name", "amount", "standard_unit", "notes", and "error" in $languageName. Do not use any other language in these fields, even if the user input or previous messages use another language.';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': localizedSystemPrompt},
      ...history,
      {
        'role': 'user',
        'content': includeReminder
            ? '$userInput\n\nReminder: return standard_unit_amount + standard_unit + multiplier (as entered quantity in that unit), plus standard_calories/standard_fat/standard_protein/standard_carbs for the standard amount. Use metric units where applicable.'
            : userInput,
      },
    ];

    final response = await _post(
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
    ).timeout(requestTimeout, onTimeout: () {
      throw StateError('OpenAI request timed out.');
    });

    if (response.statusCode >= 400) {
      throw StateError(
          'OpenAI request failed: ${response.statusCode} ${response.body}');
    }

    try {
      return _OpenAiResponsePayload(
        parsedBody: jsonDecode(response.body) as Map<String, dynamic>,
        rawBody: response.body,
      );
    } catch (_) {
      throw AiParseException(
        'Failed to parse AI response.',
        rawResponseText: response.body,
      );
    }
  }

  String _languageNameEnglish(String languageCode) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == languageCode) {
        return lookupAppLocalizations(locale).languageNameEnglish;
      }
    }
    return lookupAppLocalizations(const Locale('en')).languageNameEnglish;
  }

  Map<String, dynamic> _parseResponse(_OpenAiResponsePayload responsePayload) {
    final response = responsePayload.parsedBody;
    final rawBody = responsePayload.rawBody;
    final content = _extractResponseText(response);
    if (content == null || content.isEmpty) {
      throw AiParseException(
        'Empty content in response.',
        rawResponseText: rawBody,
      );
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw AiParseException(
        'Failed to parse AI response.',
        rawResponseText: content.isNotEmpty ? content : rawBody,
      );
    }
    final errorMessage = (parsed['error'] as String?)?.trim();
    if (errorMessage != null && errorMessage.isNotEmpty) {
      throw StateError('$aiSaysErrorPrefix$errorMessage');
    }

    final items = parsed['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      throw AiParseException(
        'AI returned no items and no explanation.',
        rawResponseText: content.isNotEmpty ? content : rawBody,
      );
    }

    for (final item in items) {
      final map = item as Map<String, dynamic>;
      final name = map['name'] as String? ?? '';
      final amount = map['amount'] as String? ?? '';
      final standardUnit = map['standard_unit'] as String? ?? '';
      final standardUnitAmount = map['standard_unit_amount'];
      final multiplier = map['multiplier'];
      final standardCalories = map['standard_calories'];
      final standardFat = map['standard_fat'];
      final standardProtein = map['standard_protein'];
      final standardCarbs = map['standard_carbs'];
      if (name.trim().isEmpty || amount.trim().isEmpty) {
        throw AiParseException(
          'Missing name or amount.',
          rawResponseText: content.isNotEmpty ? content : rawBody,
        );
      }
      if (standardUnit.trim().isEmpty) {
        throw AiParseException(
          'Missing or invalid standard unit.',
          rawResponseText: content.isNotEmpty ? content : rawBody,
        );
      }
      if (standardUnitAmount is! num || standardUnitAmount <= 0) {
        throw AiParseException(
          'Missing or invalid standard unit amount.',
          rawResponseText: content.isNotEmpty ? content : rawBody,
        );
      }
      if (multiplier is! num || multiplier <= 0) {
        throw AiParseException(
          'Missing or invalid multiplier.',
          rawResponseText: content.isNotEmpty ? content : rawBody,
        );
      }
      if (standardCalories is! num || standardCalories <= 0) {
        throw AiParseException(
          'Missing or invalid standard calories.',
          rawResponseText: content.isNotEmpty ? content : rawBody,
        );
      }
      if (standardFat is! num || standardFat < 0) {
        throw AiParseException(
          'Missing or invalid standard fat.',
          rawResponseText: content.isNotEmpty ? content : rawBody,
        );
      }
      if (standardProtein is! num || standardProtein < 0) {
        throw AiParseException(
          'Missing or invalid standard protein.',
          rawResponseText: content.isNotEmpty ? content : rawBody,
        );
      }
      if (standardCarbs is! num || standardCarbs < 0) {
        throw AiParseException(
          'Missing or invalid standard carbs.',
          rawResponseText: content.isNotEmpty ? content : rawBody,
        );
      }

      final parsedMultiplier = multiplier.toDouble();
      final parsedStandardUnitAmount = standardUnitAmount.toDouble();
      final parsedStandardCalories = standardCalories.toDouble();
      final parsedStandardFat = standardFat.toDouble();
      final parsedStandardProtein = standardProtein.toDouble();
      final parsedStandardCarbs = standardCarbs.toDouble();
      final ratio = FoodItem.multiplierRatio(
        multiplier: parsedMultiplier,
        standardUnitAmount: parsedStandardUnitAmount,
      );
      map['standard_unit_amount'] = parsedStandardUnitAmount;
      map['multiplier'] = parsedMultiplier;
      map['standard_calories'] = parsedStandardCalories;
      map['standard_fat'] = parsedStandardFat;
      map['standard_protein'] = parsedStandardProtein;
      map['standard_carbs'] = parsedStandardCarbs;
      map['calories'] = (parsedStandardCalories * ratio).round();
      map['fat'] = parsedStandardFat * ratio;
      map['protein'] = parsedStandardProtein * ratio;
      map['carbs'] = parsedStandardCarbs * ratio;
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

class _OpenAiResponsePayload {
  const _OpenAiResponsePayload({
    required this.parsedBody,
    required this.rawBody,
  });

  final Map<String, dynamic> parsedBody;
  final String rawBody;
}
