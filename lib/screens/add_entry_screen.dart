import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/entries_repository.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';

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
        _errorMessage = 'Failed to fetch calories. ${_displayError(error)}';
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
      date: _entryDate,
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
          content: SizedBox(
            width: 460,
            height: 180,
            child: TextField(
              controller: controller,
              autofocus: true,
              textAlignVertical: TextAlignVertical.top,
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
            SizedBox(
              width: 110,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            SizedBox(
              width: 110,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Send'),
              ),
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
            focusNode: _inputFocusNode,
            decoration: const InputDecoration(
              labelText: 'Food and amounts',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: OutlineInputBorder(),
            ),
            minLines: 5,
            maxLines: 10,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading
                ? null
                : () {
                    final text = _inputController.text.trim();
                    if (text.isEmpty) {
                      setState(() => _errorMessage = 'Please enter food items.');
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
                  child: FilledButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _refineResponse,
                    child: const Text('Refine'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _saveEntry,
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

  String _formatGrams(dynamic value) {
    if (value is! num) {
      return '0';
    }
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

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
                    Text('Calories: ${(item['calories'] as num).round()} kcal'),
                    Text(
                      'Fat: ${_formatGrams(item['fat'])} g',
                    ),
                    Text(
                      'Protein: ${_formatGrams(item['protein'])} g',
                    ),
                    Text(
                      'Carbs: ${_formatGrams(item['carbs'])} g',
                    ),
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
