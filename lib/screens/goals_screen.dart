import 'dart:async';

import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../widgets/labeled_input_box.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  static const routeName = '/goals';

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final TextEditingController _calorieGoalController = TextEditingController();
  final TextEditingController _fatGoalController = TextEditingController();
  final TextEditingController _proteinGoalController = TextEditingController();
  final TextEditingController _carbsGoalController = TextEditingController();
  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance.settings;
    _calorieGoalController.text = settings.dailyGoal.toString();
    _fatGoalController.text = settings.dailyFatGoal.toString();
    _proteinGoalController.text = settings.dailyProteinGoal.toString();
    _carbsGoalController.text = settings.dailyCarbsGoal.toString();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _calorieGoalController.dispose();
    _fatGoalController.dispose();
    _proteinGoalController.dispose();
    _carbsGoalController.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 350), () async {
      await _saveGoals();
    });
  }

  Future<void> _saveGoals() async {
    final current = SettingsService.instance.settings;
    final dailyGoal = int.tryParse(_calorieGoalController.text.trim()) ?? current.dailyGoal;
    final dailyFatGoal = int.tryParse(_fatGoalController.text.trim()) ?? current.dailyFatGoal;
    final dailyProteinGoal =
        int.tryParse(_proteinGoalController.text.trim()) ?? current.dailyProteinGoal;
    final dailyCarbsGoal = int.tryParse(_carbsGoalController.text.trim()) ?? current.dailyCarbsGoal;
    await SettingsService.instance.updateSettings(
      AppSettings(
        languageCode: current.languageCode,
        model: current.model,
        reasoningEffort: current.reasoningEffort,
        maxOutputTokens: current.maxOutputTokens,
        openAiTimeoutSeconds: current.openAiTimeoutSeconds,
        dailyGoal: dailyGoal,
        dailyFatGoal: dailyFatGoal,
        dailyProteinGoal: dailyProteinGoal,
        dailyCarbsGoal: dailyCarbsGoal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const controlSpacing = UiConstants.largeSpacing;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined),
            const SizedBox(width: UiConstants.appBarIconTextSpacing),
            Text(l10n.goalsSectionTitle),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(UiConstants.pagePadding),
        children: [
          LabeledInputBox(
            label: l10n.dailyCalorieGoalLabel,
            controller: _calorieGoalController,
            contentHeight: UiConstants.settingsFieldHeight,
            borderColor: AppColors.calories,
            textColor: AppColors.calories,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.dailyFatGoalLabel,
            controller: _fatGoalController,
            contentHeight: UiConstants.settingsFieldHeight,
            borderColor: AppColors.fat,
            textColor: AppColors.fat,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.dailyProteinGoalLabel,
            controller: _proteinGoalController,
            contentHeight: UiConstants.settingsFieldHeight,
            borderColor: AppColors.protein,
            textColor: AppColors.protein,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.dailyCarbsGoalLabel,
            controller: _carbsGoalController,
            contentHeight: UiConstants.settingsFieldHeight,
            borderColor: AppColors.carbs,
            textColor: AppColors.carbs,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleAutosave(),
          ),
        ],
      ),
    );
  }
}
