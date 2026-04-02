import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../models/food_definition.dart';
import '../services/entries_repository.dart';
import '../theme/ui_constants.dart';
import '../utils/error_localizer.dart';
import '../widgets/food_library_browser.dart';
import 'add_new_food_screen.dart';

class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, this.date});

  static const routeName = '/add-entry';

  final DateTime? date;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  late DateTime _entryDate;
  bool _didResolveRouteArgs = false;
  int _libraryReloadToken = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _entryDate = widget.date ?? DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveRouteArgs) {
      return;
    }
    _didResolveRouteArgs = true;

    final routeDate = ModalRoute.of(context)?.settings.arguments;
    if (routeDate is DateTime) {
      _entryDate = routeDate;
    }
  }

  Future<void> _openExistingFood(FoodDefinition food) async {
    try {
      await EntriesRepository.instance.addFoodToDate(
        date: _entryDate,
        foodId: food.id,
        multiplier: food.standardUnitAmount > 0 ? food.standardUnitAmount : 1.0,
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.failedToSaveItem(localizeError(error, l10n));
        _libraryReloadToken++;
      });
    }
  }

  Future<void> _openAddNew() async {
    final result = await Navigator.pushNamed(
      context,
      AddNewFoodScreen.routeName,
      arguments: _entryDate,
    );
    if (!mounted || result != true) {
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addFoodTitle)),
      body: ListView(
        padding: const EdgeInsets.all(UiConstants.pagePadding),
        children: [
          FoodLibraryBrowser(
            reloadToken: _libraryReloadToken,
            onFoodTap: _openExistingFood,
          ),
          const SizedBox(height: UiConstants.largeSpacing),
          FilledButton.icon(
            onPressed: _openAddNew,
            icon: const Icon(Icons.add_outlined),
            label: Text(l10n.addNewButton, textAlign: TextAlign.center),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: UiConstants.mediumSpacing),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
