import 'dart:async';

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
  Timer? _autosaveTimer;
  late String _selectedModel;
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
    _autosaveTimer?.cancel();
    _apiKeyController.dispose();
    _calorieGoalController.dispose();
    _fatGoalController.dispose();
    _proteinGoalController.dispose();
    _carbsGoalController.dispose();
    super.dispose();
  }

  Future<void> _saveNonSensitiveSettings() async {
    final current = SettingsService.instance.settings;
    final dailyGoal = int.tryParse(_calorieGoalController.text.trim()) ?? current.dailyGoal;
    final dailyFatGoal = int.tryParse(_fatGoalController.text.trim()) ?? current.dailyFatGoal;
    final dailyProteinGoal =
        int.tryParse(_proteinGoalController.text.trim()) ?? current.dailyProteinGoal;
    final dailyCarbsGoal = int.tryParse(_carbsGoalController.text.trim()) ?? current.dailyCarbsGoal;
    await SettingsService.instance.updateSettings(
      AppSettings(
        model: _selectedModel,
        dailyGoal: dailyGoal,
        dailyFatGoal: dailyFatGoal,
        dailyProteinGoal: dailyProteinGoal,
        dailyCarbsGoal: dailyCarbsGoal,
      ),
    );
  }

  void _scheduleSettingsAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      const Duration(milliseconds: 350),
      () => _saveNonSensitiveSettings(),
    );
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
      await SettingsService.instance.setApiKey(apiKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key test succeeded. Key saved.')),
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
    final isBusy = _testing;
    const sectionSpacing = 24.0;
    const headerToContentSpacing = 12.0;
    const controlSpacing = 16.0;
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
          Text(
            'OpenAI',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: headerToContentSpacing),
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
          FilledButton.icon(
            onPressed: isBusy ? null : _testKey,
            icon: const Icon(Icons.vpn_key),
            label: _testing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test key', textAlign: TextAlign.center),
          ),
          const SizedBox(height: controlSpacing),
          DropdownButtonFormField<String>(
            initialValue: _selectedModel,
            decoration: const InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'gpt-5-mini',
                child: Text('GPT-5 mini'),
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
                      _scheduleSettingsAutosave();
                    }
                  },
          ),
          const SizedBox(height: sectionSpacing),
          Text(
            'Goals',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: headerToContentSpacing),
          TextField(
            controller: _calorieGoalController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: 'Daily calorie goal (kcal)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          TextField(
            controller: _fatGoalController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: 'Daily fat goal (g)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          TextField(
            controller: _proteinGoalController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: 'Daily protein goal (g)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          TextField(
            controller: _carbsGoalController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: 'Daily carbs goal (g)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: sectionSpacing),
          Text(
            'Data tools',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: headerToContentSpacing),
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
