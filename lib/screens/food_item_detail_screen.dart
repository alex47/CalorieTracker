import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
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

  String _displayError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length).trim();
    }
    if (raw.startsWith('FormatException: ')) {
      return raw.substring('FormatException: '.length).trim();
    }
    return raw;
  }

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
    final reestimateInput = await showReestimateDialog(context);

    if (reestimateInput == null || reestimateInput.isEmpty) {
      return;
    }

    final apiKey = await SettingsService.instance.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _errorMessage = 'Please set your OpenAI API key in Settings.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final settings = SettingsService.instance.settings;
      final service = OpenAIService(apiKey);

      final history = <Map<String, String>>[
        {
          'role': 'user',
          'content':
              'Current item:\n${_item.name}, ${_item.amount}, ${_item.calories} kcal, fat ${_formatGrams(_item.fat)}g, protein ${_formatGrams(_item.protein)}g, carbs ${_formatGrams(_item.carbs)}g, notes: ${_item.notes.isEmpty ? '-' : _item.notes}\n\nUpdate this item based on my correction. Return JSON with exactly one item in "items".',
        },
      ];

      final response = await service.estimateCalories(
        model: settings.model,
        userInput: reestimateInput,
        history: history,
      );

      final items = response['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) {
        throw const FormatException('Missing item in AI response.');
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
        throw const FormatException('Invalid re-estimated item in AI response.');
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
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to re-estimate item. ${_displayError(error)}';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveChanges() async {
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
        _errorMessage = 'Failed to save item. ${error.toString()}';
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
            title: const Text('Delete item'),
            content: const Text('Are you sure you want to delete this food item?'),
            actions: [
              DialogActionRow(
                alignment: MainAxisAlignment.end,
                items: [
                  DialogActionItem(
                    width: 110,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel', textAlign: TextAlign.center),
                    ),
                  ),
                  DialogActionItem(
                    width: 110,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete', textAlign: TextAlign.center),
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
        _errorMessage = 'Failed to delete item. ${error.toString()}';
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _copyToToday() async {
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
        _errorMessage = 'Failed to copy item. ${error.toString()}';
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _loading || _saving;
    return WillPopScope(
      onWillPop: () async => !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant_menu),
              SizedBox(width: 8),
              Text('Food details'),
            ],
          ),
        ),
        body: AbsorbPointer(
          absorbing: isBusy,
          child: ListView(
            padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 10),
            if (isBusy) const LinearProgressIndicator(),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 10),
            if (_canCopyToToday) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _copyToToday,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy to today', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : _deleteItem,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete', textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : _reestimateItem,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Re-estimate', textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
            if (_dirty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _saveChanges,
                  icon: const Icon(Icons.save),
                  label: const Text('Save', textAlign: TextAlign.center),
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
