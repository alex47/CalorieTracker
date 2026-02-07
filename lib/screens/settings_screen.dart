import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _calorieGoalController = TextEditingController();
  final TextEditingController _fatGoalController = TextEditingController();
  final TextEditingController _proteinGoalController = TextEditingController();
  final TextEditingController _carbsGoalController = TextEditingController();
  late String _selectedModel;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance.settings;
    _selectedModel = settings.model;
    _calorieGoalController.text = settings.dailyGoal.toString();
    _fatGoalController.text = settings.dailyFatGoal.toString();
    _proteinGoalController.text = settings.dailyProteinGoal.toString();
    _carbsGoalController.text = settings.dailyCarbsGoal.toString();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final apiKey = await SettingsService.instance.getApiKey();
    setState(() {
      _apiKeyController.text = apiKey ?? '';
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _calorieGoalController.dispose();
    _fatGoalController.dispose();
    _proteinGoalController.dispose();
    _carbsGoalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final dailyGoal = int.tryParse(_calorieGoalController.text.trim()) ?? 2000;
    final dailyFatGoal = int.tryParse(_fatGoalController.text.trim()) ?? 70;
    final dailyProteinGoal = int.tryParse(_proteinGoalController.text.trim()) ?? 150;
    final dailyCarbsGoal = int.tryParse(_carbsGoalController.text.trim()) ?? 250;
    await SettingsService.instance.setApiKey(_apiKeyController.text.trim());
    await SettingsService.instance.updateSettings(
      AppSettings(
        model: _selectedModel,
        dailyGoal: dailyGoal,
        dailyFatGoal: dailyFatGoal,
        dailyProteinGoal: dailyProteinGoal,
        dailyCarbsGoal: dailyCarbsGoal,
      ),
    );
    setState(() => _saving = false);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  String _displayError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length).trim();
    }
    return raw;
  }

  Future<void> _testKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key first.')),
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final service = OpenAIService(apiKey);
      await service.testConnection(model: _selectedModel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key test succeeded.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API key test failed: ${_displayError(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _saving || _testing;
    return WillPopScope(
      onWillPop: () async => !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('Settings'),
            ],
          ),
        ),
        body: AbsorbPointer(
          absorbing: isBusy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
            TextField(
              controller: _apiKeyController,
              enabled: !isBusy,
              decoration: const InputDecoration(
                labelText: 'OpenAI API key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isBusy ? null : _testKey,
            child: _testing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test key', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedModel,
            decoration: const InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'gpt-5-mini',
                child: Text('GPT-5 mini (default)'),
              ),
              DropdownMenuItem(
                value: 'gpt-5.2',
                child: Text('GPT-5.2'),
              ),
            ],
            onChanged: isBusy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedModel = value);
                    }
                  },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _calorieGoalController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: 'Daily calorie goal',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fatGoalController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: 'Daily fat goal (g)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _proteinGoalController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: 'Daily protein goal (g)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _carbsGoalController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: 'Daily carbs goal (g)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: isBusy ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save settings', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          Text(
            'Data tools',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: isBusy
                ? null
                : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export is coming soon.')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Export data', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: isBusy
                ? null
                : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import is coming soon.')),
              );
            },
            icon: const Icon(Icons.upload),
            label: const Text('Import data', textAlign: TextAlign.center),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
