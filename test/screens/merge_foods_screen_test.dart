import 'dart:async';

import 'package:calorie_tracker/models/food_definition.dart';
import 'package:calorie_tracker/screens/merge_foods_screen.dart';
import 'package:calorie_tracker/services/food_library_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_test_app.dart';

void main() {
  group('MergeFoodsScreen', () {
    testWidgets(
        'selects target, requires manual factors, confirms, and merges busy',
        (tester) async {
      final completer = Completer<void>();
      bool? routeResult;
      int? targetId;
      List<FoodMergeSource>? capturedSources;
      await _openMerge(
        tester,
        onResult: (result) => routeResult = result,
        screen: MergeFoodsScreen(
          foods: [
            _food(1, 'Apple', unit: 'g'),
            _food(2, 'Banana', unit: 'g'),
            _food(3, 'Milk', unit: 'ml'),
          ],
          mergeFoods: ({
            required targetFoodId,
            required sources,
          }) {
            targetId = targetFoodId;
            capturedSources = sources;
            return completer.future;
          },
        ),
      );

      expect(find.text('Choose food to keep'), findsOneWidget);
      await tester.tap(find.text('Banana'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Units differ.'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(_button('Next').onPressed, isNull);
      final fields = find.byType(TextField);
      expect((tester.widget<TextField>(fields.first).controller?.text), '1');

      await tester.enterText(fields.last, '2,5');
      await tester.pump();
      expect(_button('Next').onPressed, isNotNull);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Keep'), findsOneWidget);
      expect(find.textContaining('Remove: Apple'), findsOneWidget);
      expect(find.textContaining('Remove: Milk'), findsOneWidget);
      await tester.tap(find.text('Merge foods'));
      await tester.pump();

      expect(targetId, 2);
      expect(
        {
          for (final source in capturedSources!)
            source.sourceFoodId: source.conversionFactor,
        },
        {1: 1.0, 3: 2.5},
      );
      expect(_button('Merge foods').onPressed, isNull);
      expect(
        find.descendant(
          of: _buttonFinder('Merge foods'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      completer.complete();
      await tester.pumpAndSettle();
      expect(routeResult, isTrue);
      expect(find.text('Open merge'), findsOneWidget);
    });

    testWidgets('shows merge failures and re-enables the wizard',
        (tester) async {
      await _openMerge(
        tester,
        screen: MergeFoodsScreen(
          foods: [
            _food(1, 'Apple', unit: 'g'),
            _food(2, 'Banana', unit: 'g'),
          ],
          mergeFoods: ({
            required targetFoodId,
            required sources,
          }) async {
            throw StateError('merge failed');
          },
        ),
      );

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(
          (tester.widget<TextField>(find.byType(TextField))).controller?.text,
          '1');
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.tap(find.text('Merge foods'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to merge foods.'), findsOneWidget);
      expect(find.textContaining('merge failed'), findsOneWidget);
      expect(find.text('Merge foods'), findsWidgets);
      expect(_button('Merge foods').onPressed, isNotNull);
    });
  });
}

Future<void> _openMerge(
  WidgetTester tester, {
  required MergeFoodsScreen screen,
  ValueChanged<bool?>? onResult,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    localizedTestApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => screen),
                );
                onResult?.call(result);
              },
              child: const Text('Open merge'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open merge'));
  await tester.pumpAndSettle();
}

Finder _buttonFinder(String label) {
  return find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      )
      .first;
}

ButtonStyleButton _button(String label) {
  return _buttonFinder(label).evaluate().single.widget as ButtonStyleButton;
}

FoodDefinition _food(
  int id,
  String name, {
  required String unit,
}) {
  return FoodDefinition(
    id: id,
    name: name,
    standardUnit: unit,
    standardUnitAmount: 100,
    standardCalories: 100,
    standardFat: 1,
    standardProtein: 2,
    standardCarbs: 3,
    notes: '',
    createdAtIso: '2026-01-01T00:00:00.000',
    updatedAtIso: '2026-01-01T00:00:00.000',
    isVisibleInLibrary: true,
    usageCount: id,
  );
}
