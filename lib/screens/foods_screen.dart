import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_definition.dart';
import '../theme/ui_constants.dart';
import '../widgets/food_library_browser.dart';
import 'food_definition_screen.dart';
import 'merge_foods_screen.dart';

class FoodsScreen extends StatefulWidget {
  const FoodsScreen({super.key});

  static const routeName = '/foods';

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> {
  final Set<int> _selectedIds = <int>{};
  List<FoodDefinition> _visibleFoods = const <FoodDefinition>[];

  bool get _selectionMode => _selectedIds.isNotEmpty;

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
      setState(() {});
    }
  }

  Future<void> _mergeSelected() async {
    final selectedFoods = _visibleFoods.where((food) => _selectedIds.contains(food.id)).toList();
    if (selectedFoods.length < 2) {
      return;
    }
    final merged = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MergeFoodsScreen(foods: selectedFoods),
          ),
        ) ??
        false;
    if (!merged) {
      return;
    }
    setState(() {
      _selectedIds.clear();
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
                      onPressed: _mergeSelected,
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
            FoodLibraryBrowser(
              selectedIds: _selectedIds,
              onFoodsChanged: (foods) {
                _visibleFoods = foods;
              },
              onFoodTap: (food) async {
                if (_selectionMode) {
                  _toggleSelection(food.id);
                  return;
                }
                await _openFoodEditor(food: food);
              },
              onFoodLongPress: (food) => _toggleSelection(food.id),
            ),
          ],
        ),
      ),
    );
  }
}
