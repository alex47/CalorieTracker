import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/app_defaults.dart';
import '../models/app_settings.dart';
import '../services/data_transfer_service.dart';
import '../services/entries_repository.dart';
import '../services/metabolic_profile_history_service.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../theme/ui_constants.dart';
import '../utils/error_localizer.dart';
import '../widgets/app_dialog.dart';
import '../widgets/dialog_action_row.dart';
import '../widgets/labeled_dropdown_box.dart';
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
  final TextEditingController _openAiTimeoutController = TextEditingController();
  Timer? _autosaveTimer;
  late String _selectedLanguageCode;
  late String _selectedModel;
  late String _selectedReasoningEffort;
  bool _testing = false;
  bool _loadingModels = false;
  bool _dataTransferBusy = false;
  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance.settings;
    _selectedLanguageCode = settings.languageCode;
    _selectedModel = settings.model;
    _selectedReasoningEffort = settings.reasoningEffort;
    _maxOutputTokensController.text = settings.maxOutputTokens.toString();
    _openAiTimeoutController.text = settings.openAiTimeoutSeconds.toString();
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
    _openAiTimeoutController.dispose();
    super.dispose();
  }

  Future<void> _saveNonSensitiveSettings() async {
    final current = SettingsService.instance.settings;
    final shouldSaveSelectedModel =
        _availableModels.isNotEmpty && _availableModels.contains(_selectedModel);
    final maxOutputTokens =
        int.tryParse(_maxOutputTokensController.text.trim()) ?? current.maxOutputTokens;
    final openAiTimeoutSeconds =
        int.tryParse(_openAiTimeoutController.text.trim()) ?? current.openAiTimeoutSeconds;
    await SettingsService.instance.updateSettings(
      AppSettings(
        languageCode: _selectedLanguageCode,
        model: shouldSaveSelectedModel ? _selectedModel : current.model,
        reasoningEffort: _selectedReasoningEffort,
        maxOutputTokens: maxOutputTokens < AppDefaults.minOutputTokens
            ? current.maxOutputTokens
            : maxOutputTokens,
        openAiTimeoutSeconds:
            openAiTimeoutSeconds <= 0 ? current.openAiTimeoutSeconds : openAiTimeoutSeconds,
      ),
    );
  }

  void _scheduleSettingsAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(
      AppDefaults.settingsAutosaveDebounce,
      () async {
        try {
          await _saveNonSensitiveSettings();
        } catch (error, stackTrace) {
          debugPrint('Settings autosave failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      },
    );
  }

  Future<void> _loadModelsForApiKey(String apiKey, {required bool showError}) async {
    setState(() => _loadingModels = true);
    try {
      final service = OpenAIService(
        apiKey,
        requestTimeout: Duration(seconds: SettingsService.instance.settings.openAiTimeoutSeconds),
      );
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
      final service = OpenAIService(
        apiKey,
        requestTimeout: Duration(seconds: SettingsService.instance.settings.openAiTimeoutSeconds),
      );
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

  Future<void> _exportData() async {
    final l10n = AppLocalizations.of(context)!;
    final includeApiKey = await _confirmIncludeApiKeyInExport(l10n);
    if (!mounted || includeApiKey == null) {
      return;
    }

    setState(() => _dataTransferBusy = true);
    try {
      final apiKey = includeApiKey ? await SettingsService.instance.getApiKey() : null;
      final path = await DataTransferService.instance.exportData(
        includeApiKey: includeApiKey,
        apiKey: apiKey,
      );
      if (!mounted) {
        return;
      }
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportCancelled)),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSuccess(path))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed(localizeError(error, l10n)))),
      );
    } finally {
      if (mounted) {
        setState(() => _dataTransferBusy = false);
      }
    }
  }

  Future<void> _importData() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _dataTransferBusy = true);
    try {
      final payload = await DataTransferService.instance.pickImportData();
      if (!mounted) {
        return;
      }
      if (payload == null) {
        return;
      }
      final rollbackPayload = ImportPayload(
        settings: Map<String, String>.from(SettingsService.instance.exportSettingsMap()),
        metabolicProfileHistory:
            await MetabolicProfileHistoryService.instance.exportProfileHistoryRows(),
        entries: (await EntriesRepository.instance.exportEntriesRows())
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
        entryItems: (await EntriesRepository.instance.exportEntryItemsRows())
            .map((row) => Map<String, dynamic>.from(row))
            .toList(),
      );
      final previousApiKey = await SettingsService.instance.getApiKey();
      var overwriteApiKey = false;
      if (payload.apiKeyFromBackup != null) {
        final shouldOverwrite = await _confirmOverwriteApiKeyOnImport(
          l10n: l10n,
        );
        if (!mounted) {
          return;
        }
        if (shouldOverwrite == null) {
          return;
        }
        overwriteApiKey = shouldOverwrite;
      }
      try {
        if (overwriteApiKey) {
          await SettingsService.instance.setApiKey(payload.apiKeyFromBackup!);
        }
        final summary = await DataTransferService.instance.applyImportData(payload);
        if (!mounted) {
          return;
        }
        if (overwriteApiKey) {
          _apiKeyController.text = payload.apiKeyFromBackup!;
        }
        await SettingsService.instance.initialize();
        if (!mounted) {
          return;
        }
        final current = SettingsService.instance.settings;
        setState(() {
          _selectedLanguageCode = current.languageCode;
          _selectedModel = current.model;
          _selectedReasoningEffort = current.reasoningEffort;
          _maxOutputTokensController.text = current.maxOutputTokens.toString();
          _openAiTimeoutController.text = current.openAiTimeoutSeconds.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.importSuccess(summary.entriesCount, summary.itemsCount),
            ),
          ),
        );
      } catch (error) {
        Object? rollbackError;
        try {
          await DataTransferService.instance.applyImportData(rollbackPayload);
          if (previousApiKey == null || previousApiKey.trim().isEmpty) {
            await SettingsService.instance.clearApiKey();
          } else {
            await SettingsService.instance.setApiKey(previousApiKey);
          }
        } catch (restoreError) {
          rollbackError = restoreError;
        }

        if (rollbackError != null) {
          throw StateError(
            'Import failed and automatic restore also failed. '
            'Import error: $error. Restore error: $rollbackError',
          );
        }
        rethrow;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importFailed(localizeError(error, l10n)))),
      );
    } finally {
      if (mounted) {
        setState(() => _dataTransferBusy = false);
      }
    }
  }

  Future<bool?> _showBooleanDecisionDialog({
    required String title,
    required String body,
    required String trueLabel,
    required IconData trueIcon,
    required String falseLabel,
    required IconData falseIcon,
    required String cancelLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text(title),
        content: Text(body),
        actionItems: [
          DialogActionItem(
            width: UiConstants.buttonMinWidth,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: Icon(trueIcon),
              label: Text(trueLabel, textAlign: TextAlign.center),
            ),
          ),
          DialogActionItem(
            width: UiConstants.buttonMinWidth,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, false),
              icon: Icon(falseIcon),
              label: Text(falseLabel, textAlign: TextAlign.center),
            ),
          ),
          DialogActionItem(
            width: UiConstants.buttonMinWidth,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              label: Text(cancelLabel, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmIncludeApiKeyInExport(AppLocalizations l10n) {
    return _showBooleanDecisionDialog(
      title: l10n.exportIncludeApiKeyDialogTitle,
      body: l10n.exportIncludeApiKeyDialogBody,
      trueLabel: l10n.exportWithApiKeyButton,
      trueIcon: Icons.key_outlined,
      falseLabel: l10n.exportWithoutApiKeyButton,
      falseIcon: Icons.download_outlined,
      cancelLabel: l10n.cancelButton,
    );
  }

  Future<bool?> _confirmOverwriteApiKeyOnImport({
    required AppLocalizations l10n,
  }) {
    return _showBooleanDecisionDialog(
      title: l10n.importApiKeyDetectedDialogTitle,
      body: l10n.importApiKeyDetectedDialogBody,
      trueLabel: l10n.importOverwriteApiKeyButton,
      trueIcon: Icons.key_outlined,
      falseLabel: l10n.importKeepCurrentApiKeyButton,
      falseIcon: Icons.lock_open_outlined,
      cancelLabel: l10n.cancelButton,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTesting = _testing;
    final isDataTransferBusy = _dataTransferBusy;
    final isAnyBusy = isTesting || isDataTransferBusy;
    const sectionSpacing = UiConstants.sectionSpacing;
    const headerToContentSpacing = UiConstants.mediumSpacing;
    const controlSpacing = UiConstants.largeSpacing;
    return PopScope(
      canPop: !isAnyBusy,
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
          absorbing: isAnyBusy,
          child: ListView(
            padding: const EdgeInsets.all(UiConstants.pagePadding),
            children: [
          Text(
            l10n.generalSectionTitle,
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
                      lookupAppLocalizations(locale).languageNameNative,
                    ),
                  ),
                )
                .toList(),
            enabled: !isAnyBusy,
            onChanged: isAnyBusy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedLanguageCode = value);
                      _scheduleSettingsAutosave();
                    }
                  },
          ),
          const SizedBox(height: sectionSpacing),
          Text(
            l10n.openAiSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: headerToContentSpacing),
          LabeledInputBox(
            label: l10n.openAiApiKeyLabel,
            controller: _apiKeyController,
            enabled: !isAnyBusy,
            obscureText: true,
            contentHeight: UiConstants.settingsFieldHeight,
            suffixIcon: IconButton(
              onPressed: isAnyBusy
                  ? null
                  : () async {
                      final text = _apiKeyController.text.trim();
                      if (text.isEmpty) {
                        return;
                      }
                      await Clipboard.setData(ClipboardData(text: text));
                    },
              icon: const Icon(Icons.content_copy_outlined),
            ),
          ),
          const SizedBox(height: UiConstants.mediumSpacing),
          FilledButton.icon(
            onPressed: isAnyBusy ? null : _testKey,
            icon: const Icon(Icons.key_outlined),
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
            enabled: !isAnyBusy && !_loadingModels,
            onChanged: isAnyBusy || _loadingModels
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
            enabled: !isAnyBusy,
            onChanged: isAnyBusy
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
            enabled: !isAnyBusy,
            contentHeight: UiConstants.settingsFieldHeight,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleSettingsAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.openAiTimeoutSecondsLabel,
            controller: _openAiTimeoutController,
            enabled: !isAnyBusy,
            contentHeight: UiConstants.settingsFieldHeight,
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
            onPressed: isAnyBusy ? null : _exportData,
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.exportDataButton, textAlign: TextAlign.center),
          ),
          const SizedBox(height: UiConstants.buttonSpacing),
          FilledButton.icon(
            onPressed: isAnyBusy ? null : _importData,
            icon: const Icon(Icons.upload_outlined),
            label: Text(l10n.importDataButton, textAlign: TextAlign.center),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
