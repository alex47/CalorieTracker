import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_definition.dart';
import '../services/food_library_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import 'app_button.dart';
import 'labeled_input_box.dart';
import 'food_table_card.dart';

typedef FoodLibraryLoadOperation = Future<List<FoodDefinition>> Function({
  required String searchQuery,
  required bool visibleOnly,
});

class FoodLibraryBrowser extends StatefulWidget {
  const FoodLibraryBrowser({
    super.key,
    required this.onFoodTap,
    this.onFoodLongPress,
    this.selectedIds = const <int>{},
    this.reloadToken = 0,
    this.loadFoods,
    this.showRecentFoods = false,
    this.loadRecentFoods,
  });

  final ValueChanged<FoodDefinition> onFoodTap;
  final ValueChanged<FoodDefinition>? onFoodLongPress;
  final Set<int> selectedIds;
  final int reloadToken;
  final FoodLibraryLoadOperation? loadFoods;
  final bool showRecentFoods;
  final Future<List<FoodDefinition>> Function()? loadRecentFoods;

  @override
  State<FoodLibraryBrowser> createState() => _FoodLibraryBrowserState();
}

class _FoodLibraryBrowserState extends State<FoodLibraryBrowser> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<List<FoodDefinition>> _foodsFuture;
  Future<List<FoodDefinition>>? _recentFoodsFuture;

  @override
  void initState() {
    super.initState();
    _foodsFuture = _loadFoods();
    _recentFoodsFuture = _loadRecentFoods();
  }

  @override
  void didUpdateWidget(covariant FoodLibraryBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _refreshFoods();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<FoodDefinition>> _loadFoods() {
    return widget.loadFoods?.call(
          searchQuery: _searchQuery,
          visibleOnly: true,
        ) ??
        FoodLibraryService.instance.fetchFoods(
          searchQuery: _searchQuery,
          visibleOnly: true,
        );
  }

  Future<List<FoodDefinition>>? _loadRecentFoods() {
    if (!widget.showRecentFoods) {
      return null;
    }
    return widget.loadRecentFoods?.call() ??
        FoodLibraryService.instance.fetchRecentFoods();
  }

  void _refreshFoods() {
    setState(() {
      _foodsFuture = _loadFoods();
      _recentFoodsFuture = _loadRecentFoods();
    });
  }

  void _updateSearchQuery(String value) {
    _searchQuery = value;
    setState(() {
      _foodsFuture = _loadFoods();
    });
  }

  Widget _buildFoodTable(
    List<FoodDefinition> foods,
    AppLocalizations l10n,
  ) {
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
          backgroundColor: isSelected ? AppColors.selectionHighlight : null,
          borderColor: isSelected ? AppColors.selectionBorder : null,
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showRecentFoods)
          FutureBuilder<List<FoodDefinition>>(
            future: _recentFoodsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: UiConstants.mediumSpacing),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: UiConstants.mediumSpacing,
                  ),
                  child: AppButton(
                    onPressed: _refreshFoods,
                    icon: const Icon(Icons.refresh_outlined),
                    label: l10n.retryRecentFoods,
                  ),
                );
              }
              final foods = snapshot.data ?? const <FoodDefinition>[];
              if (foods.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.recentlyAddedFoods,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: UiConstants.smallSpacing),
                  _buildFoodTable(foods, l10n),
                  const SizedBox(height: UiConstants.largeSpacing),
                ],
              );
            },
          ),
        LabeledInputBox(
          controller: _searchController,
          label: l10n.searchFoodsLabel,
          contentHeight: UiConstants.settingsFieldHeight,
          suffixIcon: AppIconButton(
            onPressed: _refreshFoods,
            icon: const Icon(Icons.search_outlined),
          ),
          onChanged: _updateSearchQuery,
        ),
        const SizedBox(height: UiConstants.mediumSpacing),
        FutureBuilder<List<FoodDefinition>>(
          future: _foodsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final foods = snapshot.data ?? const <FoodDefinition>[];
            if (foods.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: UiConstants.largeSpacing),
                child: Text(l10n.noFoodsFound),
              );
            }
            return _buildFoodTable(foods, l10n);
          },
        ),
      ],
    );
  }
}
