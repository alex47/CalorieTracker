import 'dart:convert';

import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../theme/ui_constants.dart';
import '../utils/error_localizer.dart';
import '../widgets/app_dialog.dart';
import '../widgets/dialog_action_row.dart';
import '../widgets/food_breakdown_card.dart';
import '../widgets/labeled_input_box.dart';
import '../widgets/raw_ai_response_section.dart';

class AddNewFoodScreen extends StatefulWidget {
  const AddNewFoodScreen({super.key, this.date});

  static const routeName = '/add-new-food';

  final DateTime? date;

  @override
  State<AddNewFoodScreen> createState() => _AddNewFoodScreenState();
}

class _AddNewFoodScreenState extends State<AddNewFoodScreen> {
  final TextEditingController _inputController = TextEditingController();
  final List<TextEditingController> _multiplierControllers = [];
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
    for (final controller in _multiplierControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatNumberNoForcedRounding(double value) {
    final text = value.toString();
    if (text.endsWith('.0')) {
      return text.substring(0, text.length - 2);
    }
    return text;
  }

  void _rebuildMultiplierControllers(List<Map<String, dynamic>> items) {
    for (final controller in _multiplierControllers) {
      controller.dispose();
    }
    _multiplierControllers
      ..clear()
      ..addAll(
        items.map((item) {
          final multiplier = (item['multiplier'] as num?)?.toDouble() ?? 1.0;
          final safeMultiplier = multiplier > 0 ? multiplier : 1.0;
          return TextEditingController(text: _formatNumberNoForcedRounding(safeMultiplier));
        }),
      );
  }

  double? _parsePositiveDouble(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  bool _syncItemsFromMultiplierControllers() {
    if (_multiplierControllers.length != _items.length) {
      return false;
    }
    for (var i = 0; i < _multiplierControllers.length; i++) {
      final parsed = _parsePositiveDouble(_multiplierControllers[i].text);
      if (parsed == null) {
        return false;
      }
      final item = _items[i];
      final standardUnitAmount = ((item['standard_unit_amount'] as num?)?.toDouble() ?? 1.0);
      final standardCalories = ((item['standard_calories'] as num?)?.toDouble() ?? 0);
      final standardFat = ((item['standard_fat'] as num?)?.toDouble() ?? 0);
      final standardProtein = ((item['standard_protein'] as num?)?.toDouble() ?? 0);
      final standardCarbs = ((item['standard_carbs'] as num?)?.toDouble() ?? 0);
      item['multiplier'] = parsed;
      item['calories'] = FoodItem.computeCalories(
        standardCalories: standardCalories,
        multiplier: parsed,
        standardUnitAmount: standardUnitAmount,
      );
      item['fat'] = FoodItem.computeMacro(
        standardMacro: standardFat,
        multiplier: parsed,
        standardUnitAmount: standardUnitAmount,
      );
      item['protein'] = FoodItem.computeMacro(
        standardMacro: standardProtein,
        multiplier: parsed,
        standardUnitAmount: standardUnitAmount,
      );
      item['carbs'] = FoodItem.computeMacro(
        standardMacro: standardCarbs,
        multiplier: parsed,
        standardUnitAmount: standardUnitAmount,
      );
    }
    return true;
  }

  Future<void> _submitAi({required String prompt}) async {
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
      _rebuildMultiplierControllers(parsedItems);
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

  Future<bool?> _askSaveToLibrary(String foodName) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text(l10n.saveToLibraryDialogTitle),
        content: Text(l10n.saveToLibraryDialogBody(foodName)),
        actionItems: [
          DialogActionItem(
            width: UiConstants.buttonMinWidth,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l10n.saveToLibraryButton, textAlign: TextAlign.center),
            ),
          ),
          DialogActionItem(
            width: UiConstants.buttonMinWidth,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, false),
              icon: const Icon(Icons.visibility_off_outlined),
              label: Text(l10n.keepPrivateButton, textAlign: TextAlign.center),
            ),
          ),
          DialogActionItem(
            width: UiConstants.buttonMinWidth,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              label: Text(l10n.cancelButton, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAiItems() async {
    final l10n = AppLocalizations.of(context)!;
    if (_items.isEmpty) {
      setState(() => _errorMessage = l10n.requestCaloriesBeforeSaving);
      return;
    }
    if (!_syncItemsFromMultiplierControllers()) {
      setState(() => _errorMessage = l10n.invalidMultiplierValue);
      return;
    }

    final visibleFlags = <bool>[];
    for (final item in _items) {
      final decision = await _askSaveToLibrary((item['name'] as String?) ?? '');
      if (decision == null) {
        return;
      }
      visibleFlags.add(decision);
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
      visibleInLibraryFlags: visibleFlags,
    );
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBusy = _loading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addNewFoodTitle)),
      body: AbsorbPointer(
        absorbing: isBusy,
        child: ListView(
          padding: const EdgeInsets.all(UiConstants.pagePadding),
          children: [
            LabeledInputBox(
              label: l10n.foodAndAmountsLabel,
              controller: _inputController,
              enabled: !isBusy,
              minLines: 3,
              maxLines: 6,
              contentHeight: UiConstants.settingsFieldHeight,
              keyboardType: TextInputType.multiline,
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
                      _submitAi(prompt: text);
                    },
              icon: isBusy
                  ? const SizedBox(
                      height: UiConstants.loadingIndicatorSize,
                      width: UiConstants.loadingIndicatorSize,
                      child: CircularProgressIndicator(
                        strokeWidth: UiConstants.loadingIndicatorStrokeWidth,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(l10n.estimateCaloriesButton, textAlign: TextAlign.center),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: UiConstants.mediumSpacing),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_rawAiResponseText != null && _rawAiResponseText!.trim().isNotEmpty) ...[
              const SizedBox(height: UiConstants.smallSpacing),
              RawAiResponseSection(
                title: l10n.showAiResponseButton,
                responseText: _rawAiResponseText!,
              ),
            ],
            if (_items.isNotEmpty) ...[
              const SizedBox(height: UiConstants.largeSpacing),
              _AiResultsCard(
                items: _items,
                multiplierControllers: _multiplierControllers,
                onMultiplierChanged: (index, value) {
                  setState(() {
                    if (_parsePositiveDouble(value) != null) {
                      _errorMessage = null;
                    }
                  });
                },
                onComputedValuesChanged: (
                  index, {
                  required calories,
                  required fat,
                  required protein,
                  required carbs,
                  required multiplier,
                }) {
                  setState(() {
                    _items[index]['multiplier'] = multiplier;
                    _items[index]['calories'] = calories;
                    _items[index]['fat'] = fat;
                    _items[index]['protein'] = protein;
                    _items[index]['carbs'] = carbs;
                  });
                },
              ),
              const SizedBox(height: UiConstants.mediumSpacing),
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
                      onPressed: isBusy ? null : _saveAiItems,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(l10n.saveButton, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiResultsCard extends StatelessWidget {
  const _AiResultsCard({
    required this.items,
    required this.multiplierControllers,
    required this.onMultiplierChanged,
    required this.onComputedValuesChanged,
  });

  final List<Map<String, dynamic>> items;
  final List<TextEditingController> multiplierControllers;
  final void Function(int index, String value) onMultiplierChanged;
  final void Function(
    int index, {
    required int calories,
    required double fat,
    required double protein,
    required double carbs,
    required double multiplier,
  }) onComputedValuesChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final standardUnit = ((item['standard_unit'] as String?) ??
                  (item['standard_amount'] as String?) ??
                  '')
              .trim();
          return FoodBreakdownCard(
            margin: const EdgeInsets.only(bottom: UiConstants.tableRowVerticalPadding),
            name: (item['name'] as String?) ?? '',
            calories: (item['calories'] as num?)?.round() ?? 0,
            fat: (item['fat'] as num?)?.toDouble() ?? 0,
            protein: (item['protein'] as num?)?.toDouble() ?? 0,
            carbs: (item['carbs'] as num?)?.toDouble() ?? 0,
            notes: (item['notes'] as String?) ?? '',
            multiplierLabel: '${l10n.amountLabel} (${standardUnit.isEmpty ? '-' : standardUnit})',
            multiplierController: multiplierControllers[index],
            multiplierEnabled: true,
            onMultiplierChanged: (value) => onMultiplierChanged(index, value),
            standardUnitAmount: (item['standard_unit_amount'] as num?)?.toDouble() ?? 1.0,
            standardCalories: (item['standard_calories'] as num?)?.toDouble() ?? 0,
            standardFat: (item['standard_fat'] as num?)?.toDouble() ?? 0,
            standardProtein: (item['standard_protein'] as num?)?.toDouble() ?? 0,
            standardCarbs: (item['standard_carbs'] as num?)?.toDouble() ?? 0,
            onComputedValuesChanged: ({
              required calories,
              required fat,
              required protein,
              required carbs,
              required multiplier,
            }) =>
                onComputedValuesChanged(
              index,
              calories: calories,
              fat: fat,
              protein: protein,
              carbs: carbs,
              multiplier: multiplier,
            ),
          );
        }),
      ],
    );
  }
}
