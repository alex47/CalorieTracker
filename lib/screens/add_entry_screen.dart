import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/entries_repository.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, DateTime? date}) : date = date ?? DateTime.now();

  static const routeName = '/add-entry';

  final DateTime date;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final TextEditingController _inputController = TextEditingController();
  final List<Map<String, String>> _history = [];
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submit({required String prompt}) async {
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
      final response = await service.estimateCalories(
        model: settings.model,
        userInput: prompt,
        history: _history,
      );
      final parsedItems = (response['items'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      _history.add({'role': 'assistant', 'content': jsonEncode(response)});
      setState(() {
        _items = parsedItems;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to fetch calories. ${error.toString()}';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  int _totalCalories() {
    return _items.fold<int>(
      0,
      (sum, item) => sum + (item['calories'] as num? ?? 0).round(),
    );
  }

  Future<void> _saveEntry() async {
    if (_items.isEmpty) {
      setState(() => _errorMessage = 'Please request calories before saving.');
      return;
    }
    await EntriesRepository.instance.createEntryGroup(
      date: widget.date,
      prompt: _history.isNotEmpty ? _history.last['content'] ?? '' : _inputController.text,
      response: jsonEncode({'items': _items}),
      items: _items,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _refineResponse() async {
    final refinement = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Refine response'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Add corrections or more details',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (refinement == null || refinement.isEmpty) {
      return;
    }

    _history.add({'role': 'user', 'content': refinement});
    await _submit(prompt: refinement);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add food')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _inputController,
            decoration: const InputDecoration(
              labelText: 'Food and amounts',
              hintText: 'e.g. 2 slices pizza, 1 tbsp honey, 150g chicken',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading
                ? null
                : () {
                    final text = _inputController.text.trim();
                    if (text.isEmpty) {
                      setState(() => _errorMessage = 'Please enter food items.');
                      return;
                    }
                    _history.clear();
                    _history.add({'role': 'user', 'content': text});
                    _submit(prompt: text);
                  },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Estimate calories'),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          if (_items.isNotEmpty) _ResultsCard(items: _items, total: _totalCalories()),
          const SizedBox(height: 12),
          if (_items.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _refineResponse,
                    child: const Text('Refine'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveEntry,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.items, required this.total});

  final List<Map<String, dynamic>> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review estimate', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...items.map((item) {
              final notes = (item['notes'] as String?)?.trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['name']} - ${item['amount']}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text('${(item['calories'] as num).round()} kcal'),
                    if (notes != null && notes.isNotEmpty)
                      Text(
                        'Notes: $notes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              );
            }),
            const Divider(),
            Text('Total: $total kcal', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
