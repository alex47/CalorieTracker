import 'dart:async';

import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/screens/add_new_food_screen.dart';
import 'package:calorie_tracker/screens/food_definition_screen.dart';
import 'package:calorie_tracker/screens/food_item_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddNewFoodScreen', () {
    testWidgets('blocks back navigation while estimating and shows results',
        (tester) async {
      final estimateCompleter = Completer<Map<String, dynamic>>();
      String? capturedPrompt;
      List<Map<String, String>>? capturedHistory;
      await _openScreen(
        tester,
        AddNewFoodScreen(
          loadApiKey: () async => 'test-key',
          estimateCalories: ({
            required apiKey,
            required prompt,
            required history,
          }) {
            capturedPrompt = prompt;
            capturedHistory = history;
            return estimateCompleter.future;
          },
        ),
      );

      await tester.enterText(find.byType(TextField).first, '100 g apple');
      await tester.tap(find.text('Estimate calories'));
      await tester.pump();

      expect(capturedPrompt, '100 g apple');
      expect(capturedHistory, isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Add new food'), findsOneWidget);

      estimateCompleter.complete(_estimateResponse());
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('shows estimate failures', (tester) async {
      await _openScreen(
        tester,
        AddNewFoodScreen(
          loadApiKey: () async => 'test-key',
          estimateCalories: ({
            required apiKey,
            required prompt,
            required history,
          }) async {
            throw StateError('estimate failed');
          },
        ),
      );

      await tester.enterText(find.byType(TextField).first, '100 g apple');
      await tester.tap(find.text('Estimate calories'));
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to fetch calories. estimate failed'),
        findsOneWidget,
      );
    });

    testWidgets('ignores an estimate that completes after disposal',
        (tester) async {
      final estimateCompleter = Completer<Map<String, dynamic>>();
      await _openScreen(
        tester,
        AddNewFoodScreen(
          loadApiKey: () async => 'test-key',
          estimateCalories: ({
            required apiKey,
            required prompt,
            required history,
          }) =>
              estimateCompleter.future,
        ),
      );

      await tester.enterText(find.byType(TextField).first, '100 g apple');
      await tester.tap(find.text('Estimate calories'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      estimateCompleter.complete(_estimateResponse());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('blocks back navigation while saving and pops on success',
        (tester) async {
      final saveCompleter = Completer<void>();
      var saveStarted = false;
      await _openEstimatedFoodScreen(
        tester,
        saveEntryGroup: ({
          required date,
          required prompt,
          required response,
          required items,
          required visibleInLibraryFlags,
        }) {
          saveStarted = true;
          return saveCompleter.future;
        },
      );

      await _startEstimatedFoodSave(tester);
      expect(saveStarted, isTrue);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Add new food'), findsOneWidget);

      saveCompleter.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open screen'), findsOneWidget);
    });

    testWidgets('shows save failures and allows another action',
        (tester) async {
      await _openEstimatedFoodScreen(
        tester,
        saveEntryGroup: ({
          required date,
          required prompt,
          required response,
          required items,
          required visibleInLibraryFlags,
        }) async {
          throw StateError('save failed');
        },
      );

      await _startEstimatedFoodSave(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to save item. Bad state: save failed'),
        findsOneWidget,
      );
      expect(_enabledButtonWithText('Save'), findsOneWidget);
    });
  });

  group('FoodDefinitionScreen', () {
    testWidgets('blocks back navigation while saving and pops on success',
        (tester) async {
      final saveCompleter = Completer<void>();
      await _openScreen(
        tester,
        FoodDefinitionScreen(
          saveFood: ({
            required existingFood,
            required name,
            required standardUnit,
            required standardUnitAmount,
            required standardCalories,
            required standardFat,
            required standardProtein,
            required standardCarbs,
            required notes,
          }) =>
              saveCompleter.future,
        ),
      );
      await _fillFoodDefinition(tester);

      await _tapVisible(tester, find.text('Save'));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Add food definition'), findsOneWidget);

      saveCompleter.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open screen'), findsOneWidget);
    });

    testWidgets('shows save failures and re-enables saving', (tester) async {
      await _openScreen(
        tester,
        FoodDefinitionScreen(
          saveFood: ({
            required existingFood,
            required name,
            required standardUnit,
            required standardUnitAmount,
            required standardCalories,
            required standardFat,
            required standardProtein,
            required standardCarbs,
            required notes,
          }) async {
            throw StateError('definition save failed');
          },
        ),
      );
      await _fillFoodDefinition(tester);

      await _tapVisible(tester, find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('definition save failed'), findsOneWidget);
      expect(_enabledButtonWithText('Save'), findsOneWidget);
    });

    testWidgets('ignores a save that completes after disposal', (tester) async {
      final saveCompleter = Completer<void>();
      await _openScreen(
        tester,
        FoodDefinitionScreen(
          saveFood: ({
            required existingFood,
            required name,
            required standardUnit,
            required standardUnitAmount,
            required standardCalories,
            required standardFat,
            required standardProtein,
            required standardCarbs,
            required notes,
          }) =>
              saveCompleter.future,
        ),
      );
      await _fillFoodDefinition(tester);
      await _tapVisible(tester, find.text('Save'));
      await tester.pumpWidget(const SizedBox());

      saveCompleter.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('FoodItemDetailScreen', () {
    testWidgets('blocks back navigation while saving and pops on success',
        (tester) async {
      final saveCompleter = Completer<void>();
      await _openScreen(
        tester,
        FoodItemDetailScreen(
          item: _foodItem(),
          itemDate: _yesterday(),
          saveItem: ({
            required item,
            required date,
            required isNew,
            required multiplier,
          }) =>
              saveCompleter.future,
        ),
      );

      await _tapVisible(tester, find.text('Save'));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Food details'), findsOneWidget);

      saveCompleter.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open screen'), findsOneWidget);
    });

    testWidgets('shows save failures and re-enables all actions',
        (tester) async {
      await _openScreen(
        tester,
        FoodItemDetailScreen(
          item: _foodItem(),
          itemDate: _yesterday(),
          saveItem: ({
            required item,
            required date,
            required isNew,
            required multiplier,
          }) async {
            throw StateError('item save failed');
          },
        ),
      );

      await _tapVisible(tester, find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('item save failed'), findsOneWidget);
      expect(_enabledButtonWithText('Delete'), findsOneWidget);
      expect(_enabledButtonWithText('Copy to today'), findsOneWidget);
      expect(_enabledButtonWithText('Save'), findsOneWidget);
    });

    testWidgets('shows delete failures and keeps the screen open',
        (tester) async {
      await _openScreen(
        tester,
        FoodItemDetailScreen(
          item: _foodItem(),
          itemDate: _yesterday(),
          deleteItem: (item) async {
            throw StateError('delete failed');
          },
        ),
      );

      await _tapVisible(tester, find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('delete failed'), findsOneWidget);
      expect(find.text('Food details'), findsOneWidget);
      expect(_enabledButtonWithText('Delete'), findsOneWidget);
    });

    testWidgets('pops after a successful delete', (tester) async {
      var deleted = false;
      await _openScreen(
        tester,
        FoodItemDetailScreen(
          item: _foodItem(),
          itemDate: _yesterday(),
          deleteItem: (item) async {
            deleted = true;
          },
        ),
      );

      await _tapVisible(tester, find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(find.text('Open screen'), findsOneWidget);
    });

    testWidgets('shows copy failures and keeps the screen open',
        (tester) async {
      await _openScreen(
        tester,
        FoodItemDetailScreen(
          item: _foodItem(),
          itemDate: _yesterday(),
          copyItem: ({required item, required date}) async {
            throw StateError('copy failed');
          },
        ),
      );

      await _tapVisible(tester, find.text('Copy to today'));
      await tester.pumpAndSettle();

      expect(find.textContaining('copy failed'), findsOneWidget);
      expect(find.text('Food details'), findsOneWidget);
      expect(_enabledButtonWithText('Copy to today'), findsOneWidget);
    });

    testWidgets('pops after a successful copy', (tester) async {
      var copied = false;
      await _openScreen(
        tester,
        FoodItemDetailScreen(
          item: _foodItem(),
          itemDate: _yesterday(),
          copyItem: ({required item, required date}) async {
            copied = true;
          },
        ),
      );

      await _tapVisible(tester, find.text('Copy to today'));
      await tester.pumpAndSettle();

      expect(copied, isTrue);
      expect(find.text('Open screen'), findsOneWidget);
    });

    testWidgets('ignores a save that completes after disposal', (tester) async {
      final saveCompleter = Completer<void>();
      await _openScreen(
        tester,
        FoodItemDetailScreen(
          item: _foodItem(),
          itemDate: _yesterday(),
          saveItem: ({
            required item,
            required date,
            required isNew,
            required multiplier,
          }) =>
              saveCompleter.future,
        ),
      );

      await _tapVisible(tester, find.text('Save'));
      await tester.pumpWidget(const SizedBox());

      saveCompleter.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _testApp(Widget screen) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(useMaterial3: true),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => screen),
            ),
            child: const Text('Open screen'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_testApp(screen));
  await tester.tap(find.text('Open screen'));
  await tester.pumpAndSettle();
}

Future<void> _openEstimatedFoodScreen(
  WidgetTester tester, {
  required FoodEntryGroupSaveOperation saveEntryGroup,
}) async {
  await _openScreen(
    tester,
    AddNewFoodScreen(
      loadApiKey: () async => 'test-key',
      estimateCalories: ({
        required apiKey,
        required prompt,
        required history,
      }) async =>
          _estimateResponse(),
      saveEntryGroup: saveEntryGroup,
    ),
  );
  await tester.enterText(find.byType(TextField).first, '100 g apple');
  await tester.tap(find.text('Estimate calories'));
  await tester.pumpAndSettle();
}

Future<void> _startEstimatedFoodSave(WidgetTester tester) async {
  await _tapVisible(tester, find.text('Save'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Keep private'));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _fillFoodDefinition(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Apple');
  await tester.enterText(fields.at(1), 'g');
  await tester.enterText(fields.at(3), '52');
  await tester.enterText(fields.at(4), '0.2');
  await tester.enterText(fields.at(5), '0.3');
  await tester.enterText(fields.at(6), '14');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Finder _enabledButtonWithText(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is ButtonStyleButton &&
        widget.onPressed != null &&
        find
            .descendant(
              of: find.byWidget(widget),
              matching: find.text(text),
            )
            .evaluate()
            .isNotEmpty,
  );
}

Map<String, dynamic> _estimateResponse() {
  return {
    'items': [
      {
        'name': 'Apple',
        'amount': '100 g',
        'standard_unit': 'g',
        'standard_unit_amount': 100.0,
        'multiplier': 100.0,
        'standard_calories': 52.0,
        'standard_fat': 0.2,
        'standard_protein': 0.3,
        'standard_carbs': 14.0,
        'calories': 52,
        'fat': 0.2,
        'protein': 0.3,
        'carbs': 14.0,
        'notes': '',
      },
    ],
  };
}

FoodItem _foodItem() {
  return FoodItem(
    id: 1,
    entryId: 2,
    foodId: 3,
    name: 'Apple',
    amount: '100 g',
    calories: 52,
    fat: 0.2,
    protein: 0.3,
    carbs: 14,
    standardUnit: 'g',
    standardUnitAmount: 100,
    multiplier: 100,
    standardCalories: 52,
    standardFat: 0.2,
    standardProtein: 0.3,
    standardCarbs: 14,
    notes: '',
  );
}

DateTime _yesterday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - 1);
}
