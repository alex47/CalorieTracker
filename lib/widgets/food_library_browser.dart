import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_definition.dart';
import '../services/food_library_service.dart';
import '../theme/ui_constants.dart';
import 'labeled_input_box.dart';
import 'food_table_card.dart';

class FoodLibraryBrowser extends StatefulWidget {
  const FoodLibraryBrowser({
    super.key,
    required this.onFoodTap,
    this.onFoodLongPress,
    this.selectedIds = const <int>{},
    this.reloadToken = 0,
  });

  final ValueChanged<FoodDefinition> onFoodTap;
  final ValueChanged<FoodDefinition>? onFoodLongPress;
  final Set<int> selectedIds;
  final int reloadToken;

  @override
  State<FoodLibraryBrowser> createState() => _FoodLibraryBrowserState();
}

class _FoodLibraryBrowserState extends State<FoodLibraryBrowser> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<FoodDefinition>> _foodsFuture;

  @override
  void initState() {
    super.initState();
    _foodsFuture = _loadFoods();
  }

  @override
  void didUpdateWidget(covariant FoodLibraryBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _reload();
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        LabeledInputBox(
          controller: _searchController,
          label: l10n.searchFoodsLabel,
          contentHeight: UiConstants.settingsFieldHeight,
          suffixIcon: IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.search_outlined),
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
            return FoodTableCard(
              highlightRowsByDominantMacro: true,
              columns: buildStandardFoodTableColumns(
                firstLabel: l10n.foodLabel,
                secondLabel: l10n.standardUnitLabel,
                thirdLabel: l10n.foodUsesLabel,
              ),
              rows: foods.map((food) {
                final isSelected = widget.selectedIds.contains(food.id);
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
                  fat: food.standardFat,
                  protein: food.standardProtein,
                  carbs: food.standardCarbs,
                  onTap: () => widget.onFoodTap(food),
                  onLongPress: widget.onFoodLongPress == null
                      ? null
                      : () => widget.onFoodLongPress!(food),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
