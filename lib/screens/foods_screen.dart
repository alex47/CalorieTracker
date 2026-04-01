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
  final Map<int, FoodDefinition> _selectedFoods = <int, FoodDefinition>{};
  int _reloadToken = 0;

  bool get _selectionMode => _selectedFoods.isNotEmpty;

  void _toggleSelection(FoodDefinition food) {
    setState(() {
      if (_selectedFoods.containsKey(food.id)) {
        _selectedFoods.remove(food.id);
      } else {
        _selectedFoods[food.id] = food;
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
      setState(() {
        _reloadToken++;
      });
    }
  }

  Future<void> _mergeSelected() async {
    final selectedFoods = _selectedFoods.values.toList(growable: false);
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
      _selectedFoods.clear();
      _reloadToken++;
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
            _selectedFoods.clear();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.foodsTitle),
          actions: [
            if (_selectedFoods.length >= 2)
              IconButton(
                onPressed: _mergeSelected,
                icon: const Icon(Icons.merge_outlined),
                tooltip: l10n.mergeFoodsButton,
              ),
            IconButton(
              onPressed: () => _openFoodEditor(),
              icon: const Icon(Icons.add_outlined),
              tooltip: l10n.addButton,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(UiConstants.pagePadding),
          children: [
            FoodLibraryBrowser(
              selectedIds: _selectedFoods.keys.toSet(),
              reloadToken: _reloadToken,
              onFoodTap: (food) async {
                if (_selectionMode) {
                  _toggleSelection(food);
                  return;
                }
                await _openFoodEditor(food: food);
              },
              onFoodLongPress: _toggleSelection,
            ),
          ],
        ),
      ),
    );
  }
}
