import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';

class FoodItemDetailScreen extends StatefulWidget {
  const FoodItemDetailScreen({super.key, required this.item});

  final FoodItem item;

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

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  Future<void> _refineItem() async {
    final refinement = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Refine item'),
              content: SizedBox(
                width: 460,
                height: 180,
                child: TextField(
                  controller: controller,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Food and amounts',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(),
                  ),
                  expands: true,
                  minLines: null,
                  maxLines: null,
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: controller.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );

    if (refinement == null || refinement.isEmpty) {
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
        userInput: refinement,
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
        throw const FormatException('Invalid refined item in AI response.');
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
        _errorMessage = 'Failed to refine item. ${_displayError(error)}';
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
            title: const Text('Delete item'),
            content: const Text('Are you sure you want to delete this food item?'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailCard(
            label: 'Food',
            value: _item.name,
          ),
          const SizedBox(height: 12),
          _DetailCard(
            label: 'Amount',
            value: _item.amount,
          ),
          const SizedBox(height: 12),
          _DetailCard(
            label: 'Calories',
            value: '${_item.calories} kcal',
          ),
          const SizedBox(height: 12),
          _DetailCard(
            label: 'Fat',
            value: '${_formatGrams(_item.fat)} g',
          ),
          const SizedBox(height: 12),
          _DetailCard(
            label: 'Protein',
            value: '${_formatGrams(_item.protein)} g',
          ),
          const SizedBox(height: 12),
          _DetailCard(
            label: 'Carbs',
            value: '${_formatGrams(_item.carbs)} g',
          ),
          const SizedBox(height: 12),
          _DetailCard(
            label: 'Notes',
            value: _item.notes.trim().isEmpty ? '-' : _item.notes,
          ),
          const SizedBox(height: 12),
          if (_loading || _saving) const LinearProgressIndicator(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _loading || _saving ? null : _deleteItem,
                  child: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _loading || _saving ? null : _refineItem,
                  child: const Text('Refine'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _saving || !_dirty ? null : _saveChanges,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
