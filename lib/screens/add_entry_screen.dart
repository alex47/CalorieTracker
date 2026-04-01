import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_definition.dart';
import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/food_library_service.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../theme/ui_constants.dart';
import '../utils/error_localizer.dart';
import '../widgets/app_dialog.dart';
import '../widgets/dialog_action_row.dart';
import '../widgets/food_breakdown_card.dart';
import '../widgets/food_table_card.dart';
import '../widgets/raw_ai_response_section.dart';
import 'food_item_detail_screen.dart';

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, this.date});

  static const routeName = '/add-entry';

  final DateTime? date;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<TextEditingController> _multiplierControllers = [];
  final List<Map<String, String>> _history = [];
  List<Map<String, dynamic>> _items = [];
  late DateTime _entryDate;
  late Future<List<FoodDefinition>> _foodsFuture;
  bool _didResolveRouteArgs = false;
  bool _loading = false;
  String? _errorMessage;
  String? _rawAiResponseText;

  @override
  void initState() {
    super.initState();
    _entryDate = widget.date ?? DateTime.now();
    _foodsFuture = _loadFoods();
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
    _searchController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    for (final controller in _multiplierControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<List<FoodDefinition>> _loadFoods() {
    return FoodLibraryService.instance.fetchFoods(
      searchQuery: _searchController.text,
      visibleOnly: true,
    );
  }

  void _reloadFoods() {
    setState(() {
      _foodsFuture = _loadFoods();
    });
  }

  String _formatNumberNoForcedRounding(double value) {
    final text = value.toString();
    if (text.endsWith('.0')) {
      return text.substring(0, text.length - 2);
    }
    return text;
  }

  Future<void> _openExistingFood(FoodDefinition food) async {
    final item = FoodItem(
      id: 0,
      entryId: 0,
      foodId: food.id,
      name: food.name,
      amount: '',
      calories: food.standardCalories.round(),
      fat: food.standardFat,
      protein: food.standardProtein,
      carbs: food.standardCarbs,
      standardUnit: food.standardUnit,
      standardUnitAmount: food.standardUnitAmount,
      multiplier: food.standardUnitAmount,
      standardCalories: food.standardCalories,
      standardFat: food.standardFat,
      standardProtein: food.standardProtein,
      standardCarbs: food.standardCarbs,
      notes: food.notes,
    );
    final changed = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodItemDetailScreen(
          item: item,
          itemDate: _entryDate,
          isNew: true,
        ),
      ),
    );
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
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
      appBar: AppBar(title: Text(l10n.addFoodTitle)),
      body: AbsorbPointer(
        absorbing: isBusy,
        child: ListView(
          padding: const EdgeInsets.all(UiConstants.pagePadding),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l10n.searchFoodsLabel,
                suffixIcon: IconButton(
                  onPressed: _reloadFoods,
                  icon: const Icon(Icons.search_outlined),
                ),
              ),
              onChanged: (_) => _reloadFoods(),
            ),
            const SizedBox(height: UiConstants.mediumSpacing),
            FutureBuilder<List<FoodDefinition>>(
              future: _foodsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final foods = snapshot.data ?? const <FoodDefinition>[];
                if (foods.isEmpty) {
                  return Text(l10n.noFoodsFound);
                }
                return FoodTableCard(
                  columns: buildStandardFoodTableColumns(
                    firstLabel: l10n.foodLabel,
                    secondLabel: l10n.standardUnitLabel,
                    thirdLabel: l10n.foodUsesLabel,
                  ),
                  rows: foods.map((food) {
                    return FoodTableRowData(
                      cells: [
                        FoodTableCell(text: food.name),
                        FoodTableCell(
                          text:
                              '${food.standardUnitAmount % 1 == 0 ? food.standardUnitAmount.toInt() : food.standardUnitAmount} ${food.standardUnit}',
                        ),
                        FoodTableCell(
                          text: food.usageCount.toString(),
                          textAlign: TextAlign.end,
                        ),
                      ],
                      onTap: () => _openExistingFood(food),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: UiConstants.largeSpacing),
            TextField(
              controller: _inputController,
              enabled: !isBusy,
              focusNode: _inputFocusNode,
              decoration: InputDecoration(
                labelText: l10n.foodAndAmountsLabel,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: const OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 6,
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
