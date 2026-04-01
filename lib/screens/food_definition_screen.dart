import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_definition.dart';
import '../services/food_library_service.dart';
import '../theme/ui_constants.dart';

class FoodDefinitionScreen extends StatefulWidget {
  const FoodDefinitionScreen({
    super.key,
    this.food,
  });

  final FoodDefinition? food;

  @override
  State<FoodDefinitionScreen> createState() => _FoodDefinitionScreenState();
}

class _FoodDefinitionScreenState extends State<FoodDefinitionScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _unitAmountController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _fatController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _notesController;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.food != null;

  @override
  void initState() {
    super.initState();
    final food = widget.food;
    _nameController = TextEditingController(text: food?.name ?? '');
    _unitController = TextEditingController(text: food?.standardUnit ?? '');
    _unitAmountController = TextEditingController(
      text: food == null ? '1' : _formatNumber(food.standardUnitAmount),
    );
    _caloriesController = TextEditingController(
      text: food == null ? '' : _formatNumber(food.standardCalories),
    );
    _fatController = TextEditingController(
      text: food == null ? '' : _formatNumber(food.standardFat),
    );
    _proteinController = TextEditingController(
      text: food == null ? '' : _formatNumber(food.standardProtein),
    );
    _carbsController = TextEditingController(
      text: food == null ? '' : _formatNumber(food.standardCarbs),
    );
    _notesController = TextEditingController(text: food?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _unitAmountController.dispose();
    _caloriesController.dispose();
    _fatController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    final text = value.toString();
    if (text.endsWith('.0')) {
      return text.substring(0, text.length - 2);
    }
    return text;
  }

  double? _parseDouble(TextEditingController controller) {
    final parsed = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return null;
    }
    return parsed;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();
    final unitAmount = _parseDouble(_unitAmountController);
    final calories = _parseDouble(_caloriesController);
    final fat = _parseDouble(_fatController);
    final protein = _parseDouble(_proteinController);
    final carbs = _parseDouble(_carbsController);
    if (name.isEmpty ||
        unit.isEmpty ||
        unitAmount == null ||
        unitAmount <= 0 ||
        calories == null ||
        calories < 0 ||
        fat == null ||
        fat < 0 ||
        protein == null ||
        protein < 0 ||
        carbs == null ||
        carbs < 0) {
      setState(() {
        _errorMessage = l10n.invalidFoodDefinitionInput;
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        await FoodLibraryService.instance.updateFood(
          foodId: widget.food!.id,
          name: name,
          standardUnit: unit,
          standardUnitAmount: unitAmount,
          standardCalories: calories,
          standardFat: fat,
          standardProtein: protein,
          standardCarbs: carbs,
          notes: _notesController.text.trim(),
          isVisibleInLibrary: widget.food!.isVisibleInLibrary,
        );
      } else {
        await FoodLibraryService.instance.createFood(
          name: name,
          standardUnit: unit,
          standardUnitAmount: unitAmount,
          standardCalories: calories,
          standardFat: fat,
          standardProtein: protein,
          standardCarbs: carbs,
          notes: _notesController.text.trim(),
          isVisibleInLibrary: true,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.editFoodButton : l10n.addFoodDefinitionTitle,
        ),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(UiConstants.pagePadding),
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.foodLabel),
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            TextField(
              controller: _unitController,
              decoration: InputDecoration(labelText: l10n.standardUnitLabel),
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            TextField(
              controller: _unitAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.standardUnitAmountLabel),
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            TextField(
              controller: _caloriesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.standardCaloriesLabel),
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            TextField(
              controller: _fatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.fatLabel),
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            TextField(
              controller: _proteinController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.proteinLabel),
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            TextField(
              controller: _carbsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.carbsLabel),
            ),
            const SizedBox(height: UiConstants.smallSpacing),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(labelText: l10n.notesLabel),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: UiConstants.smallSpacing),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: UiConstants.mediumSpacing),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.saveButton, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
