import 'dart:async';

import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/app_defaults.dart';
import '../models/app_settings.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../utils/error_localizer.dart';
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
  late String _selectedLanguageCode;
  late String _selectedModel;
  late String _selectedReasoningEffort;
  bool _testing = false;
  bool _loadingModels = false;
  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance.settings;
    _selectedLanguageCode = settings.languageCode;
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
        languageCode: _selectedLanguageCode,
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.couldNotLoadModels(localizeError(error, l10n)),
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
    final l10n = AppLocalizations.of(context)!;
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterApiKeyFirst)),
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
          SnackBar(content: Text(l10n.apiKeyTestSucceeded)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.apiKeyTestFailed(localizeError(error, l10n)))),
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
    final l10n = AppLocalizations.of(context)!;
    final isBusy = _testing || _loadingModels;
    const sectionSpacing = UiConstants.sectionSpacing;
    const headerToContentSpacing = UiConstants.mediumSpacing;
    const controlSpacing = UiConstants.largeSpacing;
    return WillPopScope(
      onWillPop: () async => !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings),
              const SizedBox(width: UiConstants.appBarIconTextSpacing),
              Text(l10n.settingsTitle),
            ],
          ),
        ),
        body: AbsorbPointer(
          absorbing: isBusy,
          child: ListView(
            padding: const EdgeInsets.all(UiConstants.pagePadding),
            children: [
          Text(
            l10n.openAiSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: headerToContentSpacing),
          LabeledDropdownBox<String>(
            label: l10n.languageLabel,
            value: _selectedLanguageCode,
            contentHeight: UiConstants.settingsFieldHeight,
            items: AppLocalizations.supportedLocales
                .map(
                  (locale) => DropdownMenuItem(
                    value: locale.languageCode,
                    child: Text(
                      locale.languageCode == 'hu'
                          ? l10n.languageHungarian
                          : locale.languageCode == 'en'
                              ? l10n.languageEnglish
                              : locale.languageCode,
                    ),
                  ),
                )
                .toList(),
            enabled: !isBusy,
            onChanged: isBusy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedLanguageCode = value);
                      _scheduleSettingsAutosave();
                    }
                  },
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.openAiApiKeyLabel,
            controller: _apiKeyController,
            enabled: !isBusy,
            obscureText: true,
            contentHeight: UiConstants.settingsFieldHeight,
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
                : Text(l10n.testKeyButton, textAlign: TextAlign.center),
          ),
          const SizedBox(height: controlSpacing),
          LabeledDropdownBox<String>(
            label: l10n.modelLabel,
            value: _availableModels.contains(_selectedModel) ? _selectedModel : null,
            contentHeight: UiConstants.settingsFieldHeight,
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
            label: l10n.reasoningEffortLabel,
            value: _selectedReasoningEffort,
            contentHeight: UiConstants.settingsFieldHeight,
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
            label: l10n.maxOutputTokensLabel,
            controller: _maxOutputTokensController,
            enabled: !isBusy,
            contentHeight: UiConstants.settingsFieldHeight,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: sectionSpacing),
          Text(
            l10n.goalsSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: headerToContentSpacing),
          LabeledInputBox(
            label: l10n.dailyCalorieGoalLabel,
            controller: _calorieGoalController,
            enabled: !isBusy,
            contentHeight: UiConstants.settingsFieldHeight,
            borderColor: AppColors.calories,
            textColor: AppColors.calories,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.dailyFatGoalLabel,
            controller: _fatGoalController,
            enabled: !isBusy,
            contentHeight: UiConstants.settingsFieldHeight,
            borderColor: AppColors.fat,
            textColor: AppColors.fat,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.dailyProteinGoalLabel,
            controller: _proteinGoalController,
            enabled: !isBusy,
            contentHeight: UiConstants.settingsFieldHeight,
            borderColor: AppColors.protein,
            textColor: AppColors.protein,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.dailyCarbsGoalLabel,
            controller: _carbsGoalController,
            enabled: !isBusy,
            contentHeight: UiConstants.settingsFieldHeight,
            borderColor: AppColors.carbs,
            textColor: AppColors.carbs,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: sectionSpacing),
          Text(
            l10n.dataToolsSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: headerToContentSpacing),
          FilledButton.icon(
            onPressed: isBusy
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.exportComingSoon)),
                    );
                  },
            icon: const Icon(Icons.download),
            label: Text(l10n.exportDataButton, textAlign: TextAlign.center),
          ),
          const SizedBox(height: UiConstants.smallSpacing),
          FilledButton.icon(
            onPressed: isBusy
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.importComingSoon)),
                    );
                  },
            icon: const Icon(Icons.upload),
            label: Text(l10n.importDataButton, textAlign: TextAlign.center),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
