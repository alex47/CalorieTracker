import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/metabolic_profile.dart';
import '../services/metabolic_profile_history_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../widgets/app_dialog.dart';
import '../widgets/dialog_action_row.dart';
import '../widgets/food_table_card.dart';
import '../widgets/labeled_dropdown_box.dart';
import '../widgets/labeled_group_box.dart';
import '../widgets/labeled_input_box.dart';

class MetabolicProfileScreen extends StatefulWidget {
  const MetabolicProfileScreen({super.key});

  static const routeName = '/metabolic-profile';

  @override
  State<MetabolicProfileScreen> createState() => _MetabolicProfileScreenState();
}

class _MetabolicProfileScreenState extends State<MetabolicProfileScreen> {
  late Future<List<MetabolicProfileHistoryEntry>> _historyFuture;

  static const List<_MacroRatioPreset> _macroRatioPresets = [
    _MacroRatioPreset(
      key: _MacroRatioPreset.balancedDefaultKey,
      fatPercent: 30,
      proteinPercent: 20,
      carbsPercent: 50,
    ),
    _MacroRatioPreset(
      key: _MacroRatioPreset.fatLossHigherProteinKey,
      fatPercent: 30,
      proteinPercent: 30,
      carbsPercent: 40,
    ),
    _MacroRatioPreset(
      key: _MacroRatioPreset.bodyRecompositionTrainingKey,
      fatPercent: 30,
      proteinPercent: 35,
      carbsPercent: 35,
    ),
    _MacroRatioPreset(
      key: _MacroRatioPreset.enduranceHighActivityKey,
      fatPercent: 30,
      proteinPercent: 15,
      carbsPercent: 55,
    ),
    _MacroRatioPreset(
      key: _MacroRatioPreset.lowerCarbAppetiteControlKey,
      fatPercent: 40,
      proteinPercent: 35,
      carbsPercent: 25,
    ),
    _MacroRatioPreset(
      key: _MacroRatioPreset.highCarbPerformanceKey,
      fatPercent: 20,
      proteinPercent: 20,
      carbsPercent: 60,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _historyFuture = MetabolicProfileHistoryService.instance.fetchProfileHistory();
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _formatDateKey(DateTime date) {
    final d = _dayOnly(date);
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  void _reloadHistory() {
    setState(() {
      _historyFuture = MetabolicProfileHistoryService.instance.fetchProfileHistory();
    });
  }

  String _presetKeyForRatios({
    required int fatPercent,
    required int proteinPercent,
    required int carbsPercent,
  }) {
    for (final preset in _macroRatioPresets) {
      if (preset.fatPercent == fatPercent &&
          preset.proteinPercent == proteinPercent &&
          preset.carbsPercent == carbsPercent) {
        return preset.key;
      }
    }
    return _MacroRatioPreset.balancedDefaultKey;
  }

  String _presetLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case _MacroRatioPreset.balancedDefaultKey:
        return l10n.macroPresetBalancedDefault;
      case _MacroRatioPreset.fatLossHigherProteinKey:
        return l10n.macroPresetFatLossHigherProtein;
      case _MacroRatioPreset.bodyRecompositionTrainingKey:
        return l10n.macroPresetBodyRecompositionTraining;
      case _MacroRatioPreset.enduranceHighActivityKey:
        return l10n.macroPresetEnduranceHighActivity;
      case _MacroRatioPreset.lowerCarbAppetiteControlKey:
        return l10n.macroPresetLowerCarbAppetiteControl;
      case _MacroRatioPreset.highCarbPerformanceKey:
        return l10n.macroPresetHighCarbPerformance;
      default:
        return l10n.macroPresetBalancedDefault;
    }
  }

  Future<MetabolicProfile> _defaultProfileForAdd() async {
    final profile = await MetabolicProfileHistoryService.instance.getEffectiveProfileForDate(
      date: DateTime.now(),
    );
    if (profile != null) {
      return profile;
    }
    return const MetabolicProfile(
      age: 30,
      sex: 'male',
      heightCm: 170,
      weightKg: 70,
      activityLevel: 'bmr',
      fatRatioPercent: 30,
      proteinRatioPercent: 20,
      carbsRatioPercent: 50,
    );
  }

  Future<void> _openAddDialog({
    required Set<String> existingDateKeys,
  }) async {
    final defaultProfile = await _defaultProfileForAdd();
    if (!mounted) {
      return;
    }
    final result = await showDialog<_MetabolicProfileEditorResult>(
      context: context,
      builder: (dialogContext) => _MetabolicProfileEditorDialog(
        initialDate: _dayOnly(DateTime.now()),
        initialProfile: defaultProfile,
        initialPresetKey: _presetKeyForRatios(
          fatPercent: defaultProfile.fatRatioPercent,
          proteinPercent: defaultProfile.proteinRatioPercent,
          carbsPercent: defaultProfile.carbsRatioPercent,
        ),
        isEditing: false,
        existingDateKeys: existingDateKeys,
        macroRatioPresets: _macroRatioPresets,
        formatDateKey: _formatDateKey,
        presetLabel: _presetLabel,
      ),
    );
    await _applyDialogResult(result);
  }

  Future<void> _openEditDialog({
    required MetabolicProfileHistoryEntry entry,
    required Set<String> existingDateKeys,
  }) async {
    final result = await showDialog<_MetabolicProfileEditorResult>(
      context: context,
      builder: (dialogContext) => _MetabolicProfileEditorDialog(
        initialDate: _dayOnly(entry.profileDate),
        initialProfile: entry.profile,
        initialPresetKey: _presetKeyForRatios(
          fatPercent: entry.profile.fatRatioPercent,
          proteinPercent: entry.profile.proteinRatioPercent,
          carbsPercent: entry.profile.carbsRatioPercent,
        ),
        isEditing: true,
        existingDateKeys: existingDateKeys,
        macroRatioPresets: _macroRatioPresets,
        formatDateKey: _formatDateKey,
        presetLabel: _presetLabel,
      ),
    );
    await _applyDialogResult(result, originalDate: _dayOnly(entry.profileDate));
  }

  Future<void> _applyDialogResult(
    _MetabolicProfileEditorResult? result, {
    DateTime? originalDate,
  }) async {
    if (result == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      if (result.delete) {
        final deleteDate = result.profileDate;
        await MetabolicProfileHistoryService.instance.deleteProfileForDate(deleteDate);
        _reloadHistory();
        return;
      }

      await MetabolicProfileHistoryService.instance.upsertProfileForDate(
        date: result.profileDate,
        profile: result.profile!,
      );
      if (originalDate != null && _dayOnly(originalDate) != _dayOnly(result.profileDate)) {
        await MetabolicProfileHistoryService.instance.deleteProfileForDate(originalDate);
      }
      _reloadHistory();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToSaveItem(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monitor_weight_outlined),
            const SizedBox(width: UiConstants.appBarIconTextSpacing),
            Text(l10n.metabolicProfileTitle),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(UiConstants.pagePadding),
        children: [
          Text(
            l10n.metabolicProfileHistoryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: UiConstants.mediumSpacing),
          FutureBuilder<List<MetabolicProfileHistoryEntry>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  l10n.failedToLoadEntries,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                );
              }
              final entries = snapshot.data ?? const <MetabolicProfileHistoryEntry>[];
              final existingDateKeys = entries
                  .map((e) => _formatDateKey(e.profileDate))
                  .toSet();
              return Column(
                children: [
                  if (entries.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(l10n.noMetabolicProfileHistory),
                    )
                  else
                    FoodTableCard(
                      highlightRowsByDominantMacro: false,
                      columns: [
                        FoodTableColumn(label: l10n.profileDateLabel, flex: 5),
                        FoodTableColumn(label: l10n.weightKgLabel, flex: 4),
                      ],
                      rows: entries.map((entry) {
                        final weightText = entry.profile.weightKg % 1 == 0
                            ? entry.profile.weightKg.toStringAsFixed(0)
                            : entry.profile.weightKg.toStringAsFixed(1);
                        return FoodTableRowData(
                          onTap: () => _openEditDialog(
                            entry: entry,
                            existingDateKeys: existingDateKeys,
                          ),
                          cells: [
                            FoodTableCell(
                              text: _formatDateKey(entry.profileDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            FoodTableCell(
                              text: weightText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      }).toList(growable: false),
                    ),
                  const SizedBox(height: UiConstants.largeSpacing),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openAddDialog(existingDateKeys: existingDateKeys),
                      icon: const Icon(Icons.add_outlined),
                      label: Text(l10n.addButton, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetabolicProfileEditorDialog extends StatefulWidget {
  const _MetabolicProfileEditorDialog({
    required this.initialDate,
    required this.initialProfile,
    required this.initialPresetKey,
    required this.isEditing,
    required this.existingDateKeys,
    required this.macroRatioPresets,
    required this.formatDateKey,
    required this.presetLabel,
  });

  final DateTime initialDate;
  final MetabolicProfile initialProfile;
  final String initialPresetKey;
  final bool isEditing;
  final Set<String> existingDateKeys;
  final List<_MacroRatioPreset> macroRatioPresets;
  final String Function(DateTime) formatDateKey;
  final String Function(AppLocalizations l10n, String key) presetLabel;

  @override
  State<_MetabolicProfileEditorDialog> createState() => _MetabolicProfileEditorDialogState();
}

class _MetabolicProfileEditorDialogState extends State<_MetabolicProfileEditorDialog> {
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late DateTime _selectedDate;
  late String _selectedSex;
  late String _selectedActivityLevel;
  late String _selectedMacroPresetKey;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _selectedSex = widget.initialProfile.sex;
    _selectedActivityLevel = widget.initialProfile.activityLevel;
    _selectedMacroPresetKey = widget.initialPresetKey;
    _ageController = TextEditingController(text: widget.initialProfile.age.toString());
    _heightController = TextEditingController(
      text: widget.initialProfile.heightCm % 1 == 0
          ? widget.initialProfile.heightCm.toStringAsFixed(0)
          : widget.initialProfile.heightCm.toStringAsFixed(1),
    );
    _weightController = TextEditingController(
      text: widget.initialProfile.weightKg % 1 == 0
          ? widget.initialProfile.weightKg.toStringAsFixed(0)
          : widget.initialProfile.weightKg.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final baseTheme = Theme.of(context);
        return Theme(
          data: baseTheme.copyWith(
            datePickerTheme: baseTheme.datePickerTheme.copyWith(
              cancelButtonStyle: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll<Color>(AppColors.text),
              ),
              confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll<Color>(AppColors.text),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = _dayOnly(picked);
      _validationMessage = null;
    });
  }

  _MacroRatioPreset get _selectedMacroPreset {
    return widget.macroRatioPresets.firstWhere(
      (preset) => preset.key == _selectedMacroPresetKey,
      orElse: () => widget.macroRatioPresets.first,
    );
  }

  MetabolicProfile? _buildProfile() {
    final age = int.tryParse(_ageController.text.trim());
    final heightCm = double.tryParse(_heightController.text.trim());
    final weightKg = double.tryParse(_weightController.text.trim());
    if (age == null || heightCm == null || weightKg == null) {
      return null;
    }
    if (age <= 0 || heightCm <= 0 || weightKg <= 0) {
      return null;
    }
    final preset = _selectedMacroPreset;
    return MetabolicProfile(
      age: age,
      sex: _selectedSex,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: _selectedActivityLevel,
      fatRatioPercent: preset.fatPercent,
      proteinRatioPercent: preset.proteinPercent,
      carbsRatioPercent: preset.carbsPercent,
    );
  }

  void _save(AppLocalizations l10n) {
    final profile = _buildProfile();
    if (profile == null) {
      setState(() {
        _validationMessage = l10n.invalidMetabolicProfileInput;
      });
      return;
    }

    Navigator.of(context).pop(
      _MetabolicProfileEditorResult.save(
        profileDate: _selectedDate,
        profile: profile,
      ),
    );
  }

  Future<void> _confirmAndDelete(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AppDialog(
            title: Text(l10n.deleteProfileEntryTitle),
            content: Text(
              l10n.deleteProfileEntryConfirmMessage(
                widget.formatDateKey(_selectedDate),
              ),
            ),
            actionItems: [
              DialogActionItem(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.deleteButton, textAlign: TextAlign.center),
                ),
              ),
              DialogActionItem(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.cancelButton, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    Navigator.of(context).pop(
      _MetabolicProfileEditorResult.delete(profileDate: _selectedDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppDialog(
      title: Text(widget.isEditing ? l10n.editButton : l10n.addButton),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledGroupBox(
              label: l10n.profileDateLabel,
              value: '',
              borderColor: AppColors.subtleBorder,
              textStyle: Theme.of(context).textTheme.bodyMedium,
              backgroundColor: Colors.transparent,
              contentHeight: UiConstants.settingsFieldHeight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: UiConstants.tableRowHorizontalPadding,
              ),
              child: InkWell(
                onTap: () => _pickDate(context),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.formatDateKey(_selectedDate),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: UiConstants.largeSpacing),
            LabeledInputBox(
              label: l10n.ageLabel,
              controller: _ageController,
              contentHeight: UiConstants.settingsFieldHeight,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: UiConstants.largeSpacing),
            LabeledDropdownBox<String>(
              label: l10n.sexLabel,
              value: _selectedSex,
              contentHeight: UiConstants.settingsFieldHeight,
              items: [
                DropdownMenuItem(value: 'male', child: Text(l10n.sexMale)),
                DropdownMenuItem(value: 'female', child: Text(l10n.sexFemale)),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedSex = value);
              },
            ),
            const SizedBox(height: UiConstants.largeSpacing),
            LabeledInputBox(
              label: l10n.heightCmLabel,
              controller: _heightController,
              contentHeight: UiConstants.settingsFieldHeight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: UiConstants.largeSpacing),
            LabeledInputBox(
              label: l10n.weightKgLabel,
              controller: _weightController,
              contentHeight: UiConstants.settingsFieldHeight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: UiConstants.largeSpacing),
            LabeledDropdownBox<String>(
              label: l10n.activityLevelLabel,
              value: _selectedActivityLevel,
              contentHeight: UiConstants.settingsFieldHeight,
              items: [
                DropdownMenuItem(value: 'bmr', child: Text(l10n.activityBmr)),
                DropdownMenuItem(value: 'sedentary', child: Text(l10n.activitySedentary)),
                DropdownMenuItem(value: 'light', child: Text(l10n.activityLight)),
                DropdownMenuItem(value: 'moderate', child: Text(l10n.activityModerate)),
                DropdownMenuItem(value: 'active', child: Text(l10n.activityActive)),
                DropdownMenuItem(value: 'very_active', child: Text(l10n.activityVeryActive)),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedActivityLevel = value);
              },
            ),
            const SizedBox(height: UiConstants.largeSpacing),
            LabeledDropdownBox<String>(
              label: l10n.macroPresetLabel,
              value: _selectedMacroPresetKey,
              contentHeight: UiConstants.settingsFieldHeight,
              items: widget.macroRatioPresets.map((preset) {
                return DropdownMenuItem<String>(
                  value: preset.key,
                  child: Text(widget.presetLabel(l10n, preset.key)),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedMacroPresetKey = value);
              },
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: UiConstants.mediumSpacing),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _validationMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actionItems: [
        DialogActionItem(
          child: FilledButton.icon(
            onPressed: () => _save(l10n),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              l10n.saveButton,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (widget.isEditing)
          DialogActionItem(
            child: FilledButton.icon(
              onPressed: () => _confirmAndDelete(l10n),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.deleteButton, textAlign: TextAlign.center),
            ),
          ),
        DialogActionItem(
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: Text(l10n.cancelButton, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

class _MetabolicProfileEditorResult {
  const _MetabolicProfileEditorResult._({
    required this.profileDate,
    required this.profile,
    required this.delete,
  });

  factory _MetabolicProfileEditorResult.save({
    required DateTime profileDate,
    required MetabolicProfile profile,
  }) {
    return _MetabolicProfileEditorResult._(
      profileDate: profileDate,
      profile: profile,
      delete: false,
    );
  }

  factory _MetabolicProfileEditorResult.delete({
    required DateTime profileDate,
  }) {
    return _MetabolicProfileEditorResult._(
      profileDate: profileDate,
      profile: null,
      delete: true,
    );
  }

  final DateTime profileDate;
  final MetabolicProfile? profile;
  final bool delete;
}

class _MacroRatioPreset {
  const _MacroRatioPreset({
    required this.key,
    required this.fatPercent,
    required this.proteinPercent,
    required this.carbsPercent,
  });

  static const String balancedDefaultKey = 'balanced_default';
  static const String fatLossHigherProteinKey = 'fat_loss_higher_protein';
  static const String bodyRecompositionTrainingKey = 'body_recomposition_training';
  static const String enduranceHighActivityKey = 'endurance_high_activity';
  static const String lowerCarbAppetiteControlKey = 'lower_carb_appetite_control';
  static const String highCarbPerformanceKey = 'high_carb_performance';

  final String key;
  final int fatPercent;
  final int proteinPercent;
  final int carbsPercent;
}
