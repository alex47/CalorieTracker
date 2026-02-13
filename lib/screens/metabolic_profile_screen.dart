import 'dart:async';

import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/metabolic_profile.dart';
import '../services/metabolic_profile_history_service.dart';
import '../theme/ui_constants.dart';
import '../widgets/labeled_dropdown_box.dart';
import '../widgets/labeled_input_box.dart';

class MetabolicProfileScreen extends StatefulWidget {
  const MetabolicProfileScreen({super.key});

  static const routeName = '/metabolic-profile';

  @override
  State<MetabolicProfileScreen> createState() => _MetabolicProfileScreenState();
}

class _MetabolicProfileScreenState extends State<MetabolicProfileScreen> {
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  Timer? _autosaveTimer;
  String _selectedSex = 'male';
  String _selectedActivityLevel = 'moderate';

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final profile = await MetabolicProfileHistoryService.instance.getEffectiveProfileForDate(
      date: DateTime.now(),
    );
    if (!mounted || profile == null) {
      return;
    }
    setState(() {
      _ageController.text = profile.age.toString();
      _heightController.text = profile.heightCm.toStringAsFixed(0);
      _weightController.text = profile.weightKg % 1 == 0
          ? profile.weightKg.toStringAsFixed(0)
          : profile.weightKg.toStringAsFixed(1);
      _selectedSex = profile.sex;
      _selectedActivityLevel = profile.activityLevel;
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 350), () async {
      await _saveProfile();
    });
  }

  MetabolicProfile? _buildProfileFromInputs() {
    final age = int.tryParse(_ageController.text.trim());
    final heightCm = double.tryParse(_heightController.text.trim());
    final weightKg = double.tryParse(_weightController.text.trim());
    if (age == null || heightCm == null || weightKg == null) {
      return null;
    }
    if (age <= 0 || heightCm <= 0 || weightKg <= 0) {
      return null;
    }
    return MetabolicProfile(
      age: age,
      sex: _selectedSex,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: _selectedActivityLevel,
    );
  }

  Future<void> _saveProfile() async {
    final profile = _buildProfileFromInputs();
    if (profile == null) {
      return;
    }
    await MetabolicProfileHistoryService.instance.upsertProfileForDate(
      date: DateTime.now(),
      profile: profile,
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
            const Icon(Icons.monitor_weight_outlined),
            const SizedBox(width: UiConstants.appBarIconTextSpacing),
            Text(l10n.metabolicProfileTitle),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(UiConstants.pagePadding),
        children: [
          LabeledInputBox(
            label: l10n.ageLabel,
            controller: _ageController,
            contentHeight: UiConstants.settingsFieldHeight,
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleAutosave(),
          ),
          const SizedBox(height: controlSpacing),
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
              _scheduleAutosave();
            },
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.heightCmLabel,
            controller: _heightController,
            contentHeight: UiConstants.settingsFieldHeight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _scheduleAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledInputBox(
            label: l10n.weightKgLabel,
            controller: _weightController,
            contentHeight: UiConstants.settingsFieldHeight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _scheduleAutosave(),
          ),
          const SizedBox(height: controlSpacing),
          LabeledDropdownBox<String>(
            label: l10n.activityLevelLabel,
            value: _selectedActivityLevel,
            contentHeight: UiConstants.settingsFieldHeight,
            items: [
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
              _scheduleAutosave();
            },
          ),
        ],
      ),
    );
  }
}
