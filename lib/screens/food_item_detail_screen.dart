import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../theme/ui_constants.dart';
import '../widgets/app_button.dart';
import '../widgets/app_dialog.dart';
import '../widgets/dialog_action_row.dart';
import '../widgets/food_breakdown_card.dart';

typedef FoodItemSaveOperation = Future<void> Function({
  required FoodItem item,
  required DateTime date,
  required bool isNew,
  required double multiplier,
});

typedef FoodItemDeleteOperation = Future<void> Function(FoodItem item);

typedef FoodItemCopyOperation = Future<void> Function({
  required FoodItem item,
  required DateTime date,
});

class FoodItemDetailScreen extends StatefulWidget {
  const FoodItemDetailScreen({
    super.key,
    required this.item,
    required this.itemDate,
    this.isNew = false,
    this.saveItem,
    this.deleteItem,
    this.copyItem,
  });

  final FoodItem item;
  final DateTime itemDate;
  final bool isNew;
  final FoodItemSaveOperation? saveItem;
  final FoodItemDeleteOperation? deleteItem;
  final FoodItemCopyOperation? copyItem;

  @override
  State<FoodItemDetailScreen> createState() => _FoodItemDetailScreenState();
}

enum _FoodItemBusyAction { save, delete, copy }

class _FoodItemDetailScreenState extends State<FoodItemDetailScreen> {
  late FoodItem _item;
  late final TextEditingController _multiplierController;
  _FoodItemBusyAction? _busyAction;
  String? _errorMessage;

  bool get _isBusy => _busyAction != null;

  bool get _canCopyToToday {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final itemDay = DateTime(
        widget.itemDate.year, widget.itemDate.month, widget.itemDate.day);
    return !widget.isNew && itemDay.isBefore(today);
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _multiplierController =
        TextEditingController(text: _formatNumber(_item.multiplier));
  }

  @override
  void dispose() {
    _multiplierController.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    final text = value.toString();
    if (text.endsWith('.0')) {
      return text.substring(0, text.length - 2);
    }
    return text;
  }

  double? _parseMultiplier() {
    final value =
        double.tryParse(_multiplierController.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  Future<void> _saveChanges() async {
    if (_isBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final multiplier = _parseMultiplier();
    if (multiplier == null) {
      setState(() => _errorMessage = l10n.invalidMultiplierValue);
      return;
    }
    setState(() {
      _busyAction = _FoodItemBusyAction.save;
      _errorMessage = null;
    });
    try {
      final operation = widget.saveItem;
      if (operation != null) {
        await operation(
          item: _item,
          date: widget.itemDate,
          isNew: widget.isNew,
          multiplier: multiplier,
        );
      } else if (widget.isNew) {
        await EntriesRepository.instance.addFoodToDate(
          date: widget.itemDate,
          foodId: _item.foodId,
          multiplier: multiplier,
        );
      } else {
        await EntriesRepository.instance.updateEntryItemMultiplier(
          itemId: _item.id,
          multiplier: multiplier,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() => _busyAction = null);
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyAction = null;
        _errorMessage = l10n.failedToSaveItem(error.toString());
      });
    }
  }

  Future<void> _deleteItem() async {
    if (_isBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AppDialog(
            title: Text(l10n.deleteItemTitle),
            content: Text(l10n.deleteItemConfirmMessage),
            actionItems: [
              DialogActionItem(
                width: UiConstants.buttonMinWidth,
                child: AppButton(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.delete_outline),
                  label: l10n.deleteButton,
                ),
              ),
              DialogActionItem(
                width: UiConstants.buttonMinWidth,
                child: AppButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                  label: l10n.cancelButton,
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) {
      return;
    }
    setState(() {
      _busyAction = _FoodItemBusyAction.delete;
      _errorMessage = null;
    });
    try {
      final operation = widget.deleteItem;
      if (operation == null) {
        await EntriesRepository.instance.deleteEntryItem(_item.id);
      } else {
        await operation(_item);
      }
      if (!mounted) {
        return;
      }
      setState(() => _busyAction = null);
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyAction = null;
        _errorMessage = l10n.failedToDeleteItem(error.toString());
      });
    }
  }

  Future<void> _copyToToday() async {
    if (_isBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busyAction = _FoodItemBusyAction.copy;
      _errorMessage = null;
    });
    try {
      final today = DateTime.now();
      final operation = widget.copyItem;
      if (operation == null) {
        await EntriesRepository.instance.copyItemToDate(
          item: _item,
          date: today,
        );
      } else {
        await operation(item: _item, date: today);
      }
      if (!mounted) {
        return;
      }
      setState(() => _busyAction = null);
      Navigator.pop(context, {'reloadToday': true});
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyAction = null;
        _errorMessage = l10n.failedToCopyItem(error.toString());
      });
    }
  }

  Widget _actionIcon({
    required _FoodItemBusyAction action,
    required IconData icon,
  }) {
    if (_busyAction != action) {
      return Icon(icon);
    }
    return const SizedBox(
      height: UiConstants.loadingIndicatorSize,
      width: UiConstants.loadingIndicatorSize,
      child: CircularProgressIndicator(
        strokeWidth: UiConstants.loadingIndicatorStrokeWidth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBusy = _isBusy;
    return PopScope(
      canPop: !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? l10n.addFoodTitle : l10n.foodDetailsTitle),
        ),
        body: AbsorbPointer(
          absorbing: isBusy,
          child: ListView(
            padding: const EdgeInsets.all(UiConstants.pagePadding),
            children: [
              FoodBreakdownCard(
                name: _item.name,
                calories: _item.calories,
                fat: _item.fat,
                protein: _item.protein,
                carbs: _item.carbs,
                notes: _item.notes,
                multiplierController: _multiplierController,
                multiplierLabel:
                    '${l10n.amountLabel} (${_item.standardUnit.trim().isEmpty ? '-' : _item.standardUnit})',
                multiplierEnabled: !isBusy,
                standardUnitAmount: _item.standardUnitAmount,
                standardCalories: _item.standardCalories,
                standardFat: _item.standardFat,
                standardProtein: _item.standardProtein,
                standardCarbs: _item.standardCarbs,
                onComputedValuesChanged: ({
                  required calories,
                  required fat,
                  required protein,
                  required carbs,
                  required multiplier,
                }) {
                  setState(() {
                    _item = _item.copyWith(
                      calories: calories,
                      fat: fat,
                      protein: protein,
                      carbs: carbs,
                      multiplier: multiplier,
                    );
                  });
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: UiConstants.smallSpacing),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: UiConstants.mediumSpacing),
              if (!widget.isNew) ...[
                AppButton(
                  onPressed: isBusy ? null : _deleteItem,
                  icon: _actionIcon(
                    action: _FoodItemBusyAction.delete,
                    icon: Icons.delete_outline,
                  ),
                  label: l10n.deleteButton,
                ),
              ],
              if (_canCopyToToday) ...[
                const SizedBox(height: UiConstants.buttonSpacing),
                AppButton(
                  onPressed: isBusy ? null : _copyToToday,
                  icon: _actionIcon(
                    action: _FoodItemBusyAction.copy,
                    icon: Icons.content_copy_outlined,
                  ),
                  label: l10n.copyToTodayButton,
                ),
              ],
              const SizedBox(height: UiConstants.buttonSpacing),
              AppButton(
                onPressed: isBusy ? null : _saveChanges,
                icon: _actionIcon(
                  action: _FoodItemBusyAction.save,
                  icon: Icons.save_outlined,
                ),
                label: l10n.saveButton,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
