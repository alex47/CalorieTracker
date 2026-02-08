import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_defaults.dart';
import '../models/app_settings.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../theme/ui_constants.dart';
import '../widgets/labeled_input_box.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _maxOutputTokensController = TextEditingController();
  final TextEditingController _calorieGoalController = TextEditingController();
  final TextEditingController _fatGoalController = TextEditingController();
  final TextEditingController _proteinGoalController = TextEditingController();
  final TextEditingController _carbsGoalController = TextEditingController();
  Timer? _autosaveTimer;
  late String _selectedModel;
  late String _selectedReasoningEffort;
  bool _testing = false;
  bool _loadingModels = false;
  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance.settings;
    _selectedModel = settings.model;
    _selectedReasoningEffort = settings.reasoningEffort;
    _maxOutputTokensController.text = settings.maxOutputTokens.toString();
    _calorieGoalController.text = settings.dailyGoal.toString();
    _fatGoalController.text = settings.dailyFatGoal.toString();
    _proteinGoalController.text = settings.dailyProteinGoal.toString();
    _carbsGoalController.text = settings.dailyCarbsGoal.toString();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final apiKey = await SettingsService.instance.getApiKey();
    if (!mounted) {
      return;
    }
    setState(() {
      _apiKeyController.text = apiKey ?? '';
    });
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      await _loadModelsForApiKey(apiKey.trim(), showError: false);
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _apiKeyController.dispose();
    _maxOutputTokensController.dispose();
    _calorieGoalController.dispose();
    _fatGoalController.dispose();
    _proteinGoalController.dispose();
    _carbsGoalController.dispose();
    super.dispose();
  }

  Future<void> _saveNonSensitiveSettings() async {
    final current = SettingsService.instance.settings;
    final shouldSaveSelectedModel =
        _availableModels.isNotEmpty && _availableModels.contains(_selectedModel);
    final maxOutputTokens =
        int.tryParse(_maxOutputTokensController.text.trim()) ?? current.maxOutputTokens;
    final dailyGoal = int.tryParse(_calorieGoalController.text.trim()) ?? current.dailyGoal;
    final dailyFatGoal = int.tryParse(_fatGoalController.text.trim()) ?? current.dailyFatGoal;
    final dailyProteinGoal =
        int.tryParse(_proteinGoalController.text.trim()) ?? current.dailyProteinGoal;
    final dailyCarbsGoal = int.tryParse(_carbsGoalController.text.trim()) ?? current.dailyCarbsGoal;
    await SettingsService.instance.updateSettings(
      AppSettings(
        model: shouldSaveSelectedModel ? _selectedModel : current.model,
        reasoningEffort: _selectedReasoningEffort,
        maxOutputTokens: maxOutputTokens < AppDefaults.minOutputTokens
            ? current.maxOutputTokens
            : maxOutputTokens,
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
      AppDefaults.settingsAutosaveDebounce,
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

  Future<void> _loadModelsForApiKey(String apiKey, {required bool showError}) async {
    setState(() => _loadingModels = true);
    try {
      final service = OpenAIService(apiKey);
      final models = await service.fetchAvailableModels();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableModels = models;
        if (!_availableModels.contains(_selectedModel)) {
          _selectedModel = _availableModels.first;
          _scheduleSettingsAutosave();
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_availableModels.isEmpty) {
          _availableModels = [_selectedModel];
        } else if (!_availableModels.contains(_selectedModel)) {
          _selectedModel = _availableModels.first;
          _scheduleSettingsAutosave();
        }
      });
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not load models dynamically. ${_displayError(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingModels = false);
      }
    }
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
      await _loadModelsForApiKey(apiKey, showError: true);
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
    final isBusy = _testing || _loadingModels;
    const sectionSpacing = UiConstants.sectionSpacing;
    const headerToContentSpacing = UiConstants.mediumSpacing;
    const controlSpacing = UiConstants.largeSpacing;
    return WillPopScope(
      onWillPop: () async => !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings),
              SizedBox(width: UiConstants.appBarIconTextSpacing),
              Text('Settings'),
            ],
          ),
        ),
        body: AbsorbPointer(
          absorbing: isBusy,
          child: ListView(
            padding: const EdgeInsets.all(UiConstants.pagePadding),
            children: [
          Text(
            'OpenAI',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: headerToContentSpacing),
          LabeledInputBox(
            label: 'OpenAI API key',
            controller: _apiKeyController,
            enabled: !isBusy,
            obscureText: true,
          ),
          const SizedBox(height: UiConstants.mediumSpacing),
          FilledButton.icon(
            onPressed: isBusy ? null : _testKey,
            icon: const Icon(Icons.vpn_key),
            label: _testing
                ? const SizedBox(
                    height: UiConstants.loadingIndicatorSize,
                    width: UiConstants.loadingIndicatorSize,
                    child: CircularProgressIndicator(strokeWidth: UiConstants.loadingIndicatorStrokeWidth),
                  )
                : const Text('Test key', textAlign: TextAlign.center),
          ),
          const SizedBox(height: controlSpacing),
          LabeledDropdownBox<String>(
            label: 'Model',
            value: _availableModels.contains(_selectedModel) ? _selectedModel : null,
            items: _availableModels
                .map(
                  (model) => DropdownMenuItem(
                    value: model,
                    child: Text(model),
                  ),
                )
                .toList(),
            enabled: !isBusy,
            onChanged: isBusy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedModel = value);
                      _scheduleSettingsAutosave();
                    }
                  },
            trailing: _loadingModels
                ? const SizedBox(
                    height: UiConstants.loadingIndicatorSize,
                    width: UiConstants.loadingIndicatorSize,
                    child: CircularProgressIndicator(
                      strokeWidth: UiConstants.loadingIndicatorStrokeWidth,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: controlSpacing),
          LabeledDropdownBox<String>(
            label: 'Reasoning effort',
            value: _selectedReasoningEffort,
            items: AppDefaults.reasoningEffortOptions
                .map(
                  (effort) => DropdownMenuItem(
                    value: effort,
                    child: Text(effort),
                  ),
                )
                .toList(),
            enabled: !isBusy,
            onChanged: isBusy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedReasoningEffort = value);
                      _scheduleSettingsAutosave();
                    }
                  },
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: 'Max output tokens',
            controller: _maxOutputTokensController,
            enabled: !isBusy,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: sectionSpacing),
          Text(
            'Goals',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: headerToContentSpacing),
          LabeledInputBox(
            label: 'Daily calorie goal (kcal)',
            controller: _calorieGoalController,
            enabled: !isBusy,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: 'Daily fat goal (g)',
            controller: _fatGoalController,
            enabled: !isBusy,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: 'Daily protein goal (g)',
            controller: _proteinGoalController,
            enabled: !isBusy,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: 'Daily carbs goal (g)',
            controller: _carbsGoalController,
            enabled: !isBusy,
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
          const SizedBox(height: UiConstants.smallSpacing),
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
