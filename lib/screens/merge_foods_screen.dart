import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/food_definition.dart';
import '../services/food_library_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../widgets/labeled_group_box.dart';
import '../widgets/labeled_input_box.dart';
import '../widgets/merge_candidate_card.dart';
import '../widgets/selected_surface.dart';
import '../widgets/wizard_step_bar.dart';

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
  static const EdgeInsets _contentPadding = EdgeInsets.all(UiConstants.mediumSpacing);

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

  FoodDefinition get _targetFood =>
      widget.foods.firstWhere((food) => food.id == _selectedTargetId);

  List<FoodDefinition> get _sourceFoods => widget.foods
      .where((food) => food.id != _selectedTargetId)
      .toList(growable: false);

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
    if (target.standardUnit.trim().toLowerCase() !=
        source.standardUnit.trim().toLowerCase()) {
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

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: UiConstants.mediumSpacing),
        ...children,
      ],
    );
  }

  Widget _buildCardShell({
    required Widget child,
  }) {
    return SelectedSurface(
      selected: false,
      showBaseBorder: true,
      child: Padding(
        padding: _contentPadding,
        child: child,
      ),
    );
  }

  Widget _buildFoodSelectionStep(AppLocalizations l10n) {
    return _buildSection(
      title: l10n.chooseMergeTargetTitle,
      children: widget.foods
          .map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: UiConstants.mediumSpacing),
              child: MergeCandidateCard(
                food: food,
                selected: food.id == _selectedTargetId,
                onTap: () {
                  if (food.id == _selectedTargetId) {
                    return;
                  }
                  setState(() {
                    _selectedTargetId = food.id;
                    _rebuildFactorControllers();
                  });
                },
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildConversionsStep(AppLocalizations l10n) {
    final target = _targetFood;
    final hasCrossUnitSource = _sourceFoods.any(
      (food) =>
          food.standardUnit.trim().toLowerCase() !=
          target.standardUnit.trim().toLowerCase(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCrossUnitSource) ...[
          Text(
            l10n.mergeManualFactorHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: UiConstants.mediumSpacing),
        ],
        ..._sourceFoods.map((food) {
          final factor = _parseFactor(food.id);
          final previewTargetAmount =
              factor == null ? null : food.standardUnitAmount * factor;
          return Padding(
              padding: const EdgeInsets.only(bottom: UiConstants.largeSpacing),
              child: _buildCardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: LabeledGroupBox(
                        label: l10n.foodLabel,
                        value: food.name.trim().isEmpty ? '-' : food.name,
                        borderColor: AppColors.subtleBorder,
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    const SizedBox(height: UiConstants.smallSpacing),
                    LabeledInputBox(
                      label: l10n.mergeFactorLabel,
                      controller: _factorControllers[food.id],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      borderColor: AppColors.selectionBorder,
                      contentHeight: UiConstants.progressBarHeight,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: UiConstants.mediumSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: LabeledGroupBox(
                            label: l10n.mergeFromLabel,
                            value: _formatAmount(
                              food.standardUnitAmount,
                              food.standardUnit,
                            ),
                            borderColor: AppColors.subtleBorder,
                            textStyle: Theme.of(context).textTheme.bodyMedium,
                            contentHeight: UiConstants.progressBarHeight,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        const SizedBox(
                          width: UiConstants.smallSpacing +
                              UiConstants.groupBoxHeaderTopInset,
                        ),
                        Expanded(
                          child: LabeledGroupBox(
                            label: l10n.mergeToLabel,
                            value: previewTargetAmount == null
                                ? '-'
                                : _formatAmount(
                                    previewTargetAmount,
                                    target.standardUnit,
                                  ),
                            borderColor: AppColors.subtleBorder,
                            textStyle: Theme.of(context).textTheme.bodyMedium,
                            contentHeight: UiConstants.progressBarHeight,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ],
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
        LabeledGroupBox(
          label: l10n.mergeKeepLabel,
          value: '',
          borderColor: AppColors.green,
          textStyle: Theme.of(context).textTheme.bodyMedium,
          contentPadding: EdgeInsets.zero,
          contentHeight: null,
          backgroundColor: Colors.transparent,
          child: MergeCandidateCardContent(
            food: target,
            showNameBox: false,
            formatAmount: _formatAmount,
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
              borderColor: AppColors.red,
              textStyle: Theme.of(context).textTheme.bodyMedium,
              contentPadding: EdgeInsets.zero,
              contentHeight: null,
              backgroundColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(UiConstants.mediumSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: LabeledGroupBox(
                            label: l10n.mergeFactorLabel,
                            value: factor == null ? '-' : _formatNumber(factor),
                            borderColor: AppColors.subtleBorder,
                            textStyle: Theme.of(context).textTheme.bodyMedium,
                            contentHeight: UiConstants.progressBarHeight,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        const SizedBox(
                          width: UiConstants.smallSpacing +
                              UiConstants.groupBoxHeaderTopInset,
                        ),
                        Expanded(
                          child: LabeledGroupBox(
                            label: l10n.foodUsesLabel,
                            value: food.usageCount.toString(),
                            borderColor: AppColors.subtleBorder,
                            textStyle: Theme.of(context).textTheme.bodyMedium,
                            contentHeight: UiConstants.progressBarHeight,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: UiConstants.mediumSpacing),
                    Row(
                      children: [
                        Expanded(
                          child: LabeledGroupBox(
                            label: l10n.mergeFromLabel,
                            value: _formatAmount(
                              food.standardUnitAmount,
                              food.standardUnit,
                            ),
                            borderColor: AppColors.subtleBorder,
                            textStyle: Theme.of(context).textTheme.bodyMedium,
                            contentHeight: UiConstants.progressBarHeight,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                        const SizedBox(
                          width: UiConstants.smallSpacing +
                              UiConstants.groupBoxHeaderTopInset,
                        ),
                        Expanded(
                          child: LabeledGroupBox(
                            label: l10n.mergeToLabel,
                            value: factor == null
                                ? '-'
                                : _formatAmount(
                                    food.standardUnitAmount * factor,
                                    target.standardUnit,
                                  ),
                            borderColor: AppColors.subtleBorder,
                            textStyle: Theme.of(context).textTheme.bodyMedium,
                            contentHeight: UiConstants.progressBarHeight,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ],
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
                      : () => setState(() {
                            _stepIndex--;
                          }),
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
                        : () => setState(() {
                              _stepIndex++;
                            }),
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
            WizardStepBar(
              currentStep: _stepIndex,
              totalSteps: 3,
            ),
            const SizedBox(height: UiConstants.mediumSpacing),
            body,
          ],
        ),
      ),
    );
  }
}
