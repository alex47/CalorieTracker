import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_definition.dart';
import '../services/food_library_service.dart';
import '../theme/ui_constants.dart';
import '../widgets/app_dialog.dart';
import '../widgets/dialog_action_row.dart';
import '../widgets/food_table_card.dart';
import 'food_definition_screen.dart';

class FoodsScreen extends StatefulWidget {
  const FoodsScreen({super.key});

  static const routeName = '/foods';

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedIds = <int>{};
  late Future<List<FoodDefinition>> _foodsFuture;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _foodsFuture = _loadFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<FoodDefinition>> _loadFoods() {
    return FoodLibraryService.instance.fetchFoods(
      searchQuery: _searchController.text,
      visibleOnly: true,
    );
  }

  void _reload() {
    setState(() {
      _foodsFuture = _loadFoods();
    });
  }

  void _toggleSelection(int foodId) {
    setState(() {
      if (_selectedIds.contains(foodId)) {
        _selectedIds.remove(foodId);
      } else {
        _selectedIds.add(foodId);
      }
    });
  }

  Future<void> _openFoodEditor({FoodDefinition? food}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDefinitionScreen(food: food),
      ),
    );
    if (changed == true) {
      _reload();
    }
  }

  Future<void> _mergeSelected(List<FoodDefinition> foods) async {
    final l10n = AppLocalizations.of(context)!;
    final selectedFoods = foods.where((food) => _selectedIds.contains(food.id)).toList();
    if (selectedFoods.length < 2) {
      return;
    }
    var selectedTargetId = selectedFoods.first.id;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AppDialog(
              title: Text(l10n.chooseMergeTargetTitle),
              content: SizedBox(
                width: UiConstants.reestimateDialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.mergeFoodsConfirmMessage(selectedFoods.length)),
                    const SizedBox(height: UiConstants.mediumSpacing),
                    ...selectedFoods.map(
                      (food) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          setDialogState(() {
                            selectedTargetId = food.id;
                          });
                        },
                        leading: Icon(
                          selectedTargetId == food.id
                              ? Icons.radio_button_checked_outlined
                              : Icons.radio_button_off_outlined,
                        ),
                        title: Text(food.name),
                        subtitle: Text(l10n.foodUsageCount(food.usageCount)),
                      ),
                    ),
                  ],
                ),
              ),
              actionItems: [
                DialogActionItem(
                  width: UiConstants.buttonMinWidth,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    icon: const Icon(Icons.merge_outlined),
                    label: Text(l10n.mergeFoodsButton, textAlign: TextAlign.center),
                  ),
                ),
                DialogActionItem(
                  width: UiConstants.buttonMinWidth,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    icon: const Icon(Icons.close),
                    label: Text(l10n.cancelButton, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await FoodLibraryService.instance.mergeFoods(
      targetFoodId: selectedTargetId,
      sourceFoodIds: _selectedIds.toList(),
    );
    setState(() {
      _selectedIds.clear();
      _foodsFuture = _loadFoods();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) {
          setState(() {
            _selectedIds.clear();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.foodsTitle),
          actions: [
            IconButton(
              onPressed: () => _openFoodEditor(),
              icon: const Icon(Icons.add_outlined),
              tooltip: l10n.addButton,
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _selectedIds.length >= 2
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        final foods = await _loadFoods();
                        if (!mounted) {
                          return;
                        }
                        await _mergeSelected(foods);
                      },
                      icon: const Icon(Icons.merge_outlined),
                      label: Text(l10n.mergeFoodsButton, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              )
            : null,
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            UiConstants.pagePadding,
            UiConstants.pagePadding,
            UiConstants.pagePadding,
            _selectedIds.length >= 2
                ? UiConstants.pagePadding + kMinInteractiveDimension + UiConstants.largeSpacing
                : UiConstants.pagePadding,
          ),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l10n.searchFoodsLabel,
                suffixIcon: IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.search_outlined),
                ),
              ),
              onChanged: (_) => _reload(),
            ),
            const SizedBox(height: UiConstants.mediumSpacing),
            FutureBuilder<List<FoodDefinition>>(
              future: _foodsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final foods = snapshot.data ?? const <FoodDefinition>[];
                if (foods.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: UiConstants.largeSpacing),
                    child: Text(l10n.noFoodsFound),
                  );
                }
                return Column(
                  children: [
                    FoodTableCard(
                      columns: buildStandardFoodTableColumns(
                        firstLabel: l10n.foodLabel,
                        secondLabel: l10n.standardUnitLabel,
                        thirdLabel: l10n.foodUsesLabel,
                      ),
                      rows: foods.map((food) {
                        final isSelected = _selectedIds.contains(food.id);
                        return FoodTableRowData(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                              : null,
                          cells: [
                            FoodTableCell(text: food.name),
                            FoodTableCell(
                              text:
                                  '${food.standardUnitAmount % 1 == 0 ? food.standardUnitAmount.toInt() : food.standardUnitAmount} ${food.standardUnit}',
                            ),
                            FoodTableCell(
                              text: food.usageCount.toString(),
                              textAlign: TextAlign.end,
                            ),
                          ],
                          onTap: () async {
                            if (_selectionMode) {
                              _toggleSelection(food.id);
                              return;
                            }
                            await _openFoodEditor(food: food);
                          },
                          onLongPress: () => _toggleSelection(food.id),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
