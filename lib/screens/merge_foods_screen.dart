import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/food_definition.dart';
import '../services/food_library_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../widgets/food_breakdown_card.dart';
import '../widgets/labeled_group_box.dart';
import '../widgets/labeled_input_box.dart';

class MergeFoodsScreen extends StatefulWidget {
  const MergeFoodsScreen({
    super.key,
    required this.foods,
  });

  final List<FoodDefinition> foods;

  @override
  State<MergeFoodsScreen> createState() => _MergeFoodsScreenState();
}

class _MergeFoodsScreenState extends State<MergeFoodsScreen> {
  late int _selectedTargetId;
  final Map<int, TextEditingController> _factorControllers = <int, TextEditingController>{};
  bool _merging = false;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedTargetId = widget.foods.first.id;
    _rebuildFactorControllers();
  }

  @override
  void dispose() {
    for (final controller in _factorControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  FoodDefinition get _targetFood => widget.foods.firstWhere((food) => food.id == _selectedTargetId);

  List<FoodDefinition> get _sourceFoods => widget.foods.where((food) => food.id != _selectedTargetId).toList(growable: false);

  bool get _canMerge =>
      !_merging &&
      _sourceFoods.isNotEmpty &&
      _sourceFoods.every((food) => _parseFactor(food.id) != null);

  bool get _canAdvanceFromCurrentStep {
    switch (_stepIndex) {
      case 0:
        return true;
      case 1:
        return _sourceFoods.every((food) => _parseFactor(food.id) != null);
      case 2:
        return _canMerge;
      default:
        return false;
    }
  }

  void _rebuildFactorControllers() {
    final target = _targetFood;
    final nextControllers = <int, TextEditingController>{};
    for (final food in _sourceFoods) {
      final defaultValue = _defaultFactor(target: target, source: food);
      nextControllers[food.id] = TextEditingController(
        text: defaultValue == null ? '' : _formatNumber(defaultValue),
      );
    }
    for (final controller in _factorControllers.values) {
      controller.dispose();
    }
    _factorControllers
      ..clear()
      ..addAll(nextControllers);
  }

  double? _defaultFactor({
    required FoodDefinition target,
    required FoodDefinition source,
  }) {
    if (target.standardUnit.trim().toLowerCase() != source.standardUnit.trim().toLowerCase()) {
      return null;
    }
    final sourceAmount = source.standardUnitAmount > 0 ? source.standardUnitAmount : 1.0;
    final targetAmount = target.standardUnitAmount > 0 ? target.standardUnitAmount : 1.0;
    return targetAmount / sourceAmount;
  }

  double? _parseFactor(int foodId) {
    final raw = _factorControllers[foodId]?.text.trim().replaceAll(',', '.');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final value = double.tryParse(raw);
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  String _formatAmount(double value, String unit) {
    final displayValue = _formatNumber(value);
    return unit.isEmpty ? displayValue : '$displayValue $unit';
  }

  bool _hasMaterialNutritionDifference(FoodDefinition source, FoodDefinition target) {
    bool materiallyDifferent(double sourceValue, double targetValue) {
      final maxValue = sourceValue > targetValue ? sourceValue : targetValue;
      if (maxValue <= 0) {
        return false;
      }
      return ((sourceValue - targetValue).abs() / maxValue) >= 0.2;
    }

    return materiallyDifferent(source.standardCalories, target.standardCalories) ||
        materiallyDifferent(source.standardFat, target.standardFat) ||
        materiallyDifferent(source.standardProtein, target.standardProtein) ||
        materiallyDifferent(source.standardCarbs, target.standardCarbs);
  }

  Future<void> _merge() async {
    if (!_canMerge) {
      return;
    }
    setState(() => _merging = true);
    try {
      await FoodLibraryService.instance.mergeFoods(
        targetFoodId: _selectedTargetId,
        sources: _sourceFoods
            .map(
              (food) => FoodMergeSource(
                sourceFoodId: food.id,
                conversionFactor: _parseFactor(food.id)!,
              ),
            )
            .toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() => _merging = false);
      }
    }
  }

  int get _totalAffectedEntries =>
      _sourceFoods.fold<int>(0, (sum, food) => sum + food.usageCount);

  Widget _buildFoodSelectionStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.foods.map((food) {
          final isSelected = food.id == _selectedTargetId;
          return Padding(
            padding: const EdgeInsets.only(bottom: UiConstants.mediumSpacing),
            child: InkWell(
              borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
              onTap: () {
                if (food.id == _selectedTargetId) {
                  return;
                }
                setState(() {
                  _selectedTargetId = food.id;
                  _rebuildFactorControllers();
                });
              },
              child: AnimatedContainer(
                duration: UiConstants.homePageSnapDuration,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                ),
                padding: const EdgeInsets.all(UiConstants.smallSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: UiConstants.smallSpacing,
                        left: UiConstants.smallSpacing,
                        right: UiConstants.smallSpacing,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatAmount(food.standardUnitAmount, food.standardUnit),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            l10n.foodUsageCount(food.usageCount),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    FoodBreakdownCard(
                      name: food.name,
                      calories: food.standardCalories.round(),
                      fat: food.standardFat,
                      protein: food.standardProtein,
                      carbs: food.standardCarbs,
                      notes: food.notes,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConversionsStep(AppLocalizations l10n) {
    final target = _targetFood;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mergeConversionsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UiConstants.mediumSpacing),
        ..._sourceFoods.map((food) {
          final factor = _parseFactor(food.id);
          final previewTargetAmount = factor == null ? null : food.standardUnitAmount * factor;
          final unitsMatch =
              food.standardUnit.trim().toLowerCase() == target.standardUnit.trim().toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(bottom: UiConstants.mediumSpacing),
            child: LabeledGroupBox(
              label: food.name,
              value: '',
              borderColor: AppColors.subtleBorder,
              textStyle: Theme.of(context).textTheme.bodyMedium,
              contentHeight: null,
              backgroundColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(UiConstants.smallSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasMaterialNutritionDifference(food, target)) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(UiConstants.smallSpacing),
                        decoration: BoxDecoration(
                          color: AppColors.daySummaryIssues.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                          border: Border.all(
                            color: AppColors.daySummaryIssues.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          l10n.mergeNutritionWarning,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: UiConstants.smallSpacing),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l10n.mergeFromLabel}: ${_formatAmount(food.standardUnitAmount, food.standardUnit)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${l10n.mergeToLabel}: ${_formatAmount(target.standardUnitAmount, target.standardUnit)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: UiConstants.smallSpacing),
                    Text(
                      l10n.mergeAffectedEntriesCount(food.usageCount),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: UiConstants.smallSpacing),
                    if (!unitsMatch) ...[
                      Text(
                        l10n.mergeManualFactorHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: UiConstants.smallSpacing),
                    ],
                    LabeledInputBox(
                      label: l10n.mergeFactorLabel,
                      controller: _factorControllers[food.id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      contentHeight: UiConstants.settingsFieldHeight,
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: UiConstants.smallSpacing),
                    Text(
                      previewTargetAmount == null
                          ? l10n.mergePreviewPending
                          : l10n.mergePreviewExample(
                              _formatAmount(food.standardUnitAmount, food.standardUnit),
                              _formatAmount(previewTargetAmount, target.standardUnit),
                            ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConfirmationStep(AppLocalizations l10n) {
    final target = _targetFood;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mergeConfirmTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UiConstants.mediumSpacing),
        LabeledGroupBox(
          label: l10n.mergeKeepLabel,
          value: '',
          borderColor: AppColors.subtleBorder,
          textStyle: Theme.of(context).textTheme.bodyMedium,
          contentHeight: null,
          backgroundColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(UiConstants.smallSpacing),
            child: FoodBreakdownCard(
              name: target.name,
              calories: target.standardCalories.round(),
              fat: target.standardFat,
              protein: target.standardProtein,
              carbs: target.standardCarbs,
              notes: target.notes,
            ),
          ),
        ),
        const SizedBox(height: UiConstants.mediumSpacing),
        ..._sourceFoods.map((food) {
          final factor = _parseFactor(food.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: UiConstants.mediumSpacing),
            child: LabeledGroupBox(
              label: '${l10n.mergeRemoveLabel}: ${food.name}',
              value: '',
              borderColor: AppColors.subtleBorder,
              textStyle: Theme.of(context).textTheme.bodyMedium,
              contentHeight: null,
              backgroundColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(UiConstants.smallSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.mergeFactorLabel}: ${factor == null ? '-' : _formatNumber(factor)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: UiConstants.smallSpacing),
                    Text(
                      l10n.mergeAffectedEntriesCount(food.usageCount),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: UiConstants.smallSpacing),
                    Text(
                      l10n.mergePreviewExample(
                        _formatAmount(food.standardUnitAmount, food.standardUnit),
                        factor == null
                            ? '-'
                            : _formatAmount(
                                food.standardUnitAmount * factor,
                                target.standardUnit,
                              ),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Text(
          l10n.mergeTotalAffectedEntries(_totalAffectedEntries),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = switch (_stepIndex) {
      0 => _buildFoodSelectionStep(l10n),
      1 => _buildConversionsStep(l10n),
      _ => _buildConfirmationStep(l10n),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mergeTitle),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
        child: Row(
          children: [
            if (_stepIndex > 0)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _merging
                      ? null
                      : () {
                          setState(() {
                            _stepIndex--;
                          });
                        },
                  icon: const Icon(Icons.arrow_back_outlined),
                  label: Text(l10n.backButton),
                ),
              ),
            if (_stepIndex > 0) const SizedBox(width: UiConstants.buttonSpacing),
            Expanded(
              child: FilledButton.icon(
                onPressed: !_canAdvanceFromCurrentStep
                    ? null
                    : _stepIndex == 2
                        ? _merge
                        : () {
                            setState(() {
                              _stepIndex++;
                            });
                          },
                icon: _stepIndex == 2
                    ? (_merging
                        ? const SizedBox(
                            height: UiConstants.loadingIndicatorSize,
                            width: UiConstants.loadingIndicatorSize,
                            child: CircularProgressIndicator(
                              strokeWidth: UiConstants.loadingIndicatorStrokeWidth,
                            ),
                          )
                        : const Icon(Icons.merge_outlined))
                    : const Icon(Icons.arrow_forward_outlined),
                label: Text(
                  _stepIndex == 2 ? l10n.mergeFoodsButton : l10n.nextButton,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
      body: AbsorbPointer(
        absorbing: _merging,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UiConstants.pagePadding,
            UiConstants.pagePadding,
            UiConstants.pagePadding,
            UiConstants.pagePadding +
                kMinInteractiveDimension +
                UiConstants.largeSpacing,
          ),
          children: [
            Text(
              l10n.mergeStepIndicator(_stepIndex + 1, 3),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: UiConstants.largeSpacing),
            body,
          ],
        ),
      ),
    );
  }
}
