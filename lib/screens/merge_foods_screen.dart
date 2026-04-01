import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_definition.dart';
import '../services/food_library_service.dart';
import '../theme/ui_constants.dart';
import '../widgets/food_breakdown_card.dart';

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
  bool _merging = false;

  @override
  void initState() {
    super.initState();
    _selectedTargetId = widget.foods.first.id;
  }

  String _formatAmount(double value, String unit) {
    final displayValue = value % 1 == 0 ? value.toInt().toString() : value.toString();
    return '$displayValue $unit';
  }

  Future<void> _merge() async {
    setState(() => _merging = true);
    try {
      await FoodLibraryService.instance.mergeFoods(
        targetFoodId: _selectedTargetId,
        sourceFoodIds: widget.foods.map((food) => food.id).toList(),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mergeTitle),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: _merging ? null : _merge,
              icon: _merging
                  ? const SizedBox(
                      height: UiConstants.loadingIndicatorSize,
                      width: UiConstants.loadingIndicatorSize,
                      child: CircularProgressIndicator(
                        strokeWidth: UiConstants.loadingIndicatorStrokeWidth,
                      ),
                    )
                  : const Icon(Icons.merge_outlined),
              label: Text(l10n.mergeFoodsButton, textAlign: TextAlign.center),
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
            Text(l10n.mergeFoodsConfirmMessage(widget.foods.length)),
            const SizedBox(height: UiConstants.mediumSpacing),
            ...widget.foods.map((food) {
              final isSelected = food.id == _selectedTargetId;
              return Padding(
                padding: const EdgeInsets.only(bottom: UiConstants.mediumSpacing),
                child: InkWell(
                  borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                  onTap: () {
                    setState(() {
                      _selectedTargetId = food.id;
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
                                  _formatAmount(
                                    food.standardUnitAmount,
                                    food.standardUnit,
                                  ),
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
        ),
      ),
    );
  }
}
