import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/entries_repository.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../widgets/food_breakdown_card.dart';
import '../widgets/reestimate_dialog.dart';

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

  Future<void> _saveEntry() async {
    if (_items.isEmpty) {
      setState(() => _errorMessage = 'Please request calories before saving.');
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

  Future<void> _reestimateResponse() async {
    final reestimateInput = await showReestimateDialog(context);

    if (reestimateInput == null || reestimateInput.isEmpty) {
      return;
    }

    _history.add({'role': 'user', 'content': reestimateInput});
    await _submit(prompt: reestimateInput);
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
            enabled: !_loading,
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
            label: const Text('Estimate calories', textAlign: TextAlign.center),
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
          if (_items.isNotEmpty) _ResultsCard(items: _items),
          const SizedBox(height: 12),
          if (_items.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel', textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _reestimateResponse,
                    child: const Text('Re-estimate', textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _saveEntry,
                    child: const Text('Accept', textAlign: TextAlign.center),
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
  const _ResultsCard({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.map((item) {
          return FoodBreakdownCard(
            margin: const EdgeInsets.only(bottom: 10),
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
