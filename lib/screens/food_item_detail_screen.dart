import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../utils/error_localizer.dart';
import '../widgets/dialog_action_row.dart';
import '../widgets/food_breakdown_card.dart';
import '../widgets/reestimate_dialog.dart';

class FoodItemDetailScreen extends StatefulWidget {
  const FoodItemDetailScreen({
    super.key,
    required this.item,
    required this.itemDate,
  });

  final FoodItem item;
  final DateTime itemDate;

  @override
  State<FoodItemDetailScreen> createState() => _FoodItemDetailScreenState();
}

class _FoodItemDetailScreenState extends State<FoodItemDetailScreen> {
  late FoodItem _item;
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;
  String? _errorMessage;
  String? _rawAiResponseText;

  String _formatGrams(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool get _canCopyToToday {
    final today = _dayOnly(DateTime.now());
    final itemDay = _dayOnly(widget.itemDate);
    return itemDay.isBefore(today);
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _reestimateItem() async {
    final l10n = AppLocalizations.of(context)!;
    final reestimateInput = await showReestimateDialog(context);

    if (reestimateInput == null || reestimateInput.isEmpty) {
      return;
    }

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

      final history = <Map<String, String>>[
        {
          'role': 'user',
          'content':
              'Current item:\n${_item.name}, ${_item.amount}, ${_item.calories} kcal, fat ${_formatGrams(_item.fat)}g, protein ${_formatGrams(_item.protein)}g, carbs ${_formatGrams(_item.carbs)}g, notes: ${_item.notes.isEmpty ? '-' : _item.notes}\n\nUpdate this item based on my correction. Return JSON with exactly one item in "items".',
        },
      ];

      final response = await service.estimateCalories(
        model: settings.model,
        languageCode: settings.languageCode,
        reasoningEffort: settings.reasoningEffort,
        maxOutputTokens: settings.maxOutputTokens,
        userInput: reestimateInput,
        history: history,
      );

      final items = response['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) {
        throw FormatException(l10n.missingItemInAiResponse);
      }

      final updated = Map<String, dynamic>.from(items.first as Map);
      final name = (updated['name'] as String? ?? '').trim();
      final amount = (updated['amount'] as String? ?? '').trim();
      final calories = (updated['calories'] as num?)?.round();
      final fat = (updated['fat'] as num?)?.toDouble();
      final protein = (updated['protein'] as num?)?.toDouble();
      final carbs = (updated['carbs'] as num?)?.toDouble();
      final notes = (updated['notes'] as String? ?? '').trim();
      if (name.isEmpty ||
          amount.isEmpty ||
          calories == null ||
          calories <= 0 ||
          fat == null ||
          fat < 0 ||
          protein == null ||
          protein < 0 ||
          carbs == null ||
          carbs < 0) {
        throw FormatException(l10n.invalidReestimatedItemInAiResponse);
      }

      setState(() {
        _item = FoodItem(
          id: _item.id,
          entryId: _item.entryId,
          name: name,
          amount: amount,
          calories: calories,
          fat: fat,
          protein: protein,
          carbs: carbs,
          notes: notes,
        );
        _dirty = true;
        _rawAiResponseText = null;
      });
    } catch (error) {
      final rawResponse = error is AiParseException ? error.rawResponseText : null;
      setState(() {
        _errorMessage = l10n.failedToReestimateItem(localizeError(error, l10n));
        _rawAiResponseText = rawResponse;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showRawAiResponseDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final responseText = _rawAiResponseText;
    if (responseText == null || responseText.trim().isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiResponseDialogTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: SelectableText(responseText),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(this.context);
              await Clipboard.setData(ClipboardData(text: responseText));
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.aiResponseCopiedMessage)),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: Text(l10n.copyAiResponseButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await EntriesRepository.instance.updateEntryItem(
        itemId: _item.id,
        name: _item.name,
        amount: _item.amount,
        calories: _item.calories,
        fat: _item.fat,
        protein: _item.protein,
        carbs: _item.carbs,
        notes: _item.notes,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      setState(() {
        _errorMessage = l10n.failedToSaveItem(error.toString());
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
              side: const BorderSide(
                color: AppColors.dialogBorder,
              ),
            ),
            title: Text(l10n.deleteItemTitle),
            content: Text(l10n.deleteItemConfirmMessage),
            actions: [
              DialogActionRow(
                alignment: MainAxisAlignment.end,
                items: [
                  DialogActionItem(
                    width: UiConstants.buttonMinWidth,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.cancelButton, textAlign: TextAlign.center),
                    ),
                  ),
                  DialogActionItem(
                    width: UiConstants.buttonMinWidth,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete),
                      label: Text(l10n.deleteButton, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await EntriesRepository.instance.deleteEntryItem(_item.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      setState(() {
        _errorMessage = l10n.failedToDeleteItem(error.toString());
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _copyToToday() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await EntriesRepository.instance.copyItemToDate(
        item: _item,
        date: DateTime.now(),
      );
      if (mounted) {
        Navigator.pop(context, {'reloadToday': true});
      }
    } catch (error) {
      setState(() {
        _errorMessage = l10n.failedToCopyItem(error.toString());
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBusy = _loading || _saving;
    return PopScope(
      canPop: !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant_menu),
              const SizedBox(width: UiConstants.smallSpacing),
              Text(l10n.foodDetailsTitle),
            ],
          ),
        ),
        body: AbsorbPointer(
          absorbing: isBusy,
          child: ListView(
            padding: const EdgeInsets.all(UiConstants.pagePadding),
            children: [
            FoodBreakdownCard(
              name: _item.name,
              amount: _item.amount,
              calories: _item.calories,
              fat: _item.fat,
              protein: _item.protein,
              carbs: _item.carbs,
              notes: _item.notes,
            ),
            const SizedBox(height: UiConstants.mediumSpacing),
            if (isBusy) const LinearProgressIndicator(),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: UiConstants.smallSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    if (_rawAiResponseText != null && _rawAiResponseText!.trim().isNotEmpty) ...[
                      const SizedBox(height: UiConstants.smallSpacing),
                      TextButton.icon(
                        onPressed: _showRawAiResponseDialog,
                        icon: const Icon(Icons.article_outlined),
                        label: Text(l10n.showAiResponseButton),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: UiConstants.mediumSpacing),
            if (_canCopyToToday) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _copyToToday,
                  icon: const Icon(Icons.copy),
                  label: Text(l10n.copyToTodayButton, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: UiConstants.smallSpacing),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : _deleteItem,
                    icon: const Icon(Icons.delete),
                    label: Text(l10n.deleteButton, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: UiConstants.smallSpacing),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : _reestimateItem,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l10n.reestimateButton, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
            if (_dirty) ...[
              const SizedBox(height: UiConstants.smallSpacing),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _saveChanges,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.acceptButton, textAlign: TextAlign.center),
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
