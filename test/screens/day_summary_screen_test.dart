import 'dart:async';

import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:calorie_tracker/models/day_summary.dart';
import 'package:calorie_tracker/models/food_item.dart';
import 'package:calorie_tracker/screens/day_summary_screen.dart';
import 'package:calorie_tracker/services/day_summary_service.dart';
import 'package:calorie_tracker/services/day_summary_snapshot_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps the stored summary visible when refresh fails',
      (tester) async {
    final date = DateTime(2026, 7, 18);
    final item = _foodItem();
    final snapshot = DaySummarySnapshotBuilder.build(
      date: date,
      items: <FoodItem>[item],
      profile: null,
      maintenanceBaseline: null,
      languageCode: 'en',
    );
    final sourceHash = DaySummaryService.instance.computeSourceHash(snapshot);
    const storedSummary = DaySummary(
      summary: 'Previously saved summary.',
      highlights: <String>['Existing highlight'],
      issues: <String>['Existing issue'],
      suggestions: <String>['Existing suggestion'],
    );
    final refreshCompleter = Completer<DaySummary>();
    var refreshCalls = 0;

    await _openScreen(
      tester,
      DaySummaryScreen(
        date: date,
        loadItems: (_) async => <FoodItem>[item],
        loadProfile: (_) async => null,
        loadStoredSummary: (_) async => StoredDaySummary(
          dateKey: '2026-07-18',
          languageCode: 'en',
          model: 'gpt-5-mini',
          sourceHash: sourceHash,
          summary: storedSummary,
          createdAtIso: '2026-07-18T12:00:00.000',
          updatedAtIso: '2026-07-18T12:00:00.000',
        ),
        loadApiKey: () async => 'test-key',
        generateSummary: ({
          required apiKey,
          required model,
          required languageCode,
          required reasoningEffort,
          required maxOutputTokens,
          required daySnapshot,
        }) {
          refreshCalls += 1;
          return refreshCompleter.future;
        },
      ),
    );

    expect(find.text(storedSummary.summary), findsOneWidget);
    expect(find.text('Summarize again'), findsOneWidget);

    await tester.ensureVisible(find.text('Summarize again'));
    await tester.tap(find.text('Summarize again'));
    await tester.pump();

    expect(refreshCalls, 1);
    expect(find.text(storedSummary.summary), findsOneWidget);

    refreshCompleter.completeError(StateError('refresh failed'));
    await tester.pumpAndSettle();

    expect(find.text(storedSummary.summary), findsOneWidget);
    expect(
      find.text('Failed to summarize day. refresh failed'),
      findsOneWidget,
    );
    expect(find.text('Summarize again'), findsOneWidget);
  });
}

Widget _testApp(Widget screen) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(useMaterial3: true),
    home: screen,
  );
}

Future<void> _openScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_testApp(screen));
  await tester.pumpAndSettle();
}

FoodItem _foodItem() {
  return FoodItem(
    id: 1,
    entryId: 1,
    foodId: 1,
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
