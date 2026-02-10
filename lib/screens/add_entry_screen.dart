import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../services/entries_repository.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../theme/ui_constants.dart';
import '../utils/error_localizer.dart';
import '../widgets/food_breakdown_card.dart';
import '../widgets/raw_ai_response_section.dart';

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, this.date});

  static const routeName = '/add-entry';

  final DateTime? date;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<Map<String, String>> _history = [];
  List<Map<String, dynamic>> _items = [];
  late DateTime _entryDate;
  bool _didResolveRouteArgs = false;
  bool _loading = false;
  String? _errorMessage;
  String? _rawAiResponseText;

  @override
  void initState() {
    super.initState();
    _entryDate = widget.date ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveRouteArgs) {
      return;
    }
    _didResolveRouteArgs = true;

    final routeDate = ModalRoute.of(context)?.settings.arguments;
    if (routeDate is DateTime) {
      _entryDate = routeDate;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit({required String prompt}) async {
    final l10n = AppLocalizations.of(context)!;
    final apiKey = await SettingsService.instance.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _errorMessage = l10n.setApiKeyInSettings);
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _rawAiResponseText = null;
    });

    try {
      final settings = SettingsService.instance.settings;
      final service = OpenAIService(
        apiKey,
        requestTimeout: Duration(seconds: settings.openAiTimeoutSeconds),
      );
      final response = await service.estimateCalories(
        model: settings.model,
        languageCode: settings.languageCode,
        reasoningEffort: settings.reasoningEffort,
        maxOutputTokens: settings.maxOutputTokens,
        userInput: prompt,
        history: _history,
      );
      final parsedItems = (response['items'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      _history.add({'role': 'assistant', 'content': jsonEncode(response)});
      setState(() {
        _items = parsedItems;
        _rawAiResponseText = null;
      });
    } catch (error) {
      final rawResponse = error is AiParseException ? error.rawResponseText : null;
      setState(() {
        _errorMessage = l10n.failedToFetchCalories(localizeError(error, l10n));
        _rawAiResponseText = rawResponse;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveEntry() async {
    final l10n = AppLocalizations.of(context)!;
    if (_items.isEmpty) {
      setState(() => _errorMessage = l10n.requestCaloriesBeforeSaving);
      return;
    }
    final latestUserPrompt = _history.lastWhere(
      (item) => item['role'] == 'user',
      orElse: () => {'content': _inputController.text},
    )['content'];
    await EntriesRepository.instance.createEntryGroup(
      date: _entryDate,
      prompt: (latestUserPrompt ?? _inputController.text).trim(),
      response: jsonEncode({'items': _items}),
      items: _items,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBusy = _loading;
    return PopScope(
      canPop: !isBusy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.addFoodTitle)),
        body: AbsorbPointer(
          absorbing: isBusy,
          child: ListView(
            padding: const EdgeInsets.all(UiConstants.pagePadding),
            children: [
            TextField(
              controller: _inputController,
              enabled: !isBusy,
              focusNode: _inputFocusNode,
              decoration: InputDecoration(
                labelText: l10n.foodAndAmountsLabel,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: const OutlineInputBorder(),
              ),
              minLines: 5,
              maxLines: 10,
            ),
            const SizedBox(height: UiConstants.mediumSpacing),
            FilledButton.icon(
              onPressed: isBusy
                  ? null
                  : () {
                      final text = _inputController.text.trim();
                      if (text.isEmpty) {
                        setState(() => _errorMessage = l10n.enterFoodItems);
                        return;
                      }
                      setState(() {
                        _items = [];
                        _errorMessage = null;
                        _history.clear();
                        _history.add({'role': 'user', 'content': text});
                      });
                      _submit(prompt: text);
                    },
              icon: const Icon(Icons.auto_awesome),
              label: Text(l10n.estimateCaloriesButton, textAlign: TextAlign.center),
            ),
            const SizedBox(height: UiConstants.mediumSpacing),
            if (isBusy) const LinearProgressIndicator(),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: UiConstants.mediumSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    if (_rawAiResponseText != null && _rawAiResponseText!.trim().isNotEmpty) ...[
                      const SizedBox(height: UiConstants.smallSpacing),
                      RawAiResponseSection(
                        title: l10n.showAiResponseButton,
                        responseText: _rawAiResponseText!,
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: UiConstants.largeSpacing),
            if (_items.isNotEmpty) _ResultsCard(items: _items),
            const SizedBox(height: UiConstants.mediumSpacing),
            if (_items.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.cancelButton, textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: UiConstants.buttonSpacing),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : _saveEntry,
                      icon: const Icon(Icons.check),
                      label: Text(l10n.acceptButton, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.map((item) {
          return FoodBreakdownCard(
            margin: const EdgeInsets.only(bottom: UiConstants.tableRowVerticalPadding),
            name: (item['name'] as String?) ?? '',
            amount: (item['amount'] as String?) ?? '',
            calories: (item['calories'] as num?)?.round() ?? 0,
            fat: (item['fat'] as num?)?.toDouble() ?? 0,
            protein: (item['protein'] as num?)?.toDouble() ?? 0,
            carbs: (item['carbs'] as num?)?.toDouble() ?? 0,
            notes: (item['notes'] as String?) ?? '',
          );
        }),
      ],
    );
  }
}
