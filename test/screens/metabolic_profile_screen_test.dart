import 'package:calorie_tracker/models/metabolic_profile.dart';
import 'package:calorie_tracker/screens/metabolic_profile_screen.dart';
import 'package:calorie_tracker/services/metabolic_profile_history_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_test_app.dart';

void main() {
  group('MetabolicProfileScreen', () {
    testWidgets('adds a profile using the selected preset and reloads history',
        (tester) async {
      final history = <MetabolicProfileHistoryEntry>[];
      MetabolicProfile? createdProfile;
      DateTime? createdDate;
      var loads = 0;
      await _pumpScreen(
        tester,
        loadHistory: () async {
          loads += 1;
          return List.of(history);
        },
        createProfile: ({required date, required profile}) async {
          createdDate = date;
          createdProfile = profile;
          history.add(_entry(id: 1, date: date, profile: profile));
        },
      );

      expect(find.text('No profile history entries yet.'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(find.text('Balanced default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weight loss').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(DateUtils.dateOnly(createdDate!), DateTime(2026, 7, 20));
      expect(createdProfile?.fatRatioPercent, 30);
      expect(createdProfile?.proteinRatioPercent, 30);
      expect(createdProfile?.carbsRatioPercent, 40);
      expect(find.text('2026-07-20'), findsOneWidget);
      expect(loads, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('validates numeric input before saving', (tester) async {
      await _pumpScreen(
        tester,
        loadHistory: () async => [],
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'not a number');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Please enter valid profile values.'), findsOneWidget);
    });

    testWidgets('rejects an occupied add date before persistence',
        (tester) async {
      final history = [
        _entry(id: 1, date: DateTime(2026, 7, 20), profile: _profile),
      ];
      var createCalls = 0;
      await _pumpScreen(
        tester,
        loadHistory: () async => history,
        createProfile: ({required date, required profile}) async {
          createCalls += 1;
        },
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
        find.text('A profile already exists for this date.'),
        findsOneWidget,
      );
      expect(createCalls, 0);
    });

    testWidgets('edits and then confirms deletion of a profile',
        (tester) async {
      final history = [
        _entry(id: 7, date: DateTime(2026, 7, 19), profile: _profile),
      ];
      MetabolicProfile? updatedProfile;
      int? deletedId;
      await _pumpScreen(
        tester,
        loadHistory: () async => List.of(history),
        updateProfile: ({
          required profileId,
          required date,
          required profile,
        }) async {
          expect(profileId, 7);
          updatedProfile = profile;
          history[0] = _entry(id: profileId, date: date, profile: profile);
        },
        deleteProfile: (profileId) async {
          deletedId = profileId;
          history.clear();
        },
      );

      await tester.tap(find.text('2026-07-19'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(2), '75.5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(updatedProfile?.weightKg, 75.5);
      expect(find.text('75.5'), findsOneWidget);

      await tester.tap(find.text('2026-07-19'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete profile entry'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(deletedId, 7);
      expect(find.text('No profile history entries yet.'), findsOneWidget);
    });

    testWidgets(
        'reports persistence errors and stays usable on a narrow screen',
        (tester) async {
      await _setViewport(tester, const Size(390, 844));
      await _pumpScreen(
        tester,
        setDefaultViewport: false,
        loadHistory: () async => [],
        createProfile: ({required date, required profile}) async {
          throw StateError('profile write failed');
        },
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('profile write failed'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}

final _now = DateTime(2026, 7, 20, 12);

const _profile = MetabolicProfile(
  age: 30,
  sex: 'male',
  heightCm: 180,
  weightKg: 70,
  activityLevel: 'moderate',
  fatRatioPercent: 30,
  proteinRatioPercent: 20,
  carbsRatioPercent: 50,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ProfileHistoryLoadOperation loadHistory,
  EffectiveProfileLoadOperation? loadEffectiveProfile,
  ProfileCreateOperation? createProfile,
  ProfileUpdateOperation? updateProfile,
  ProfileDeleteOperation? deleteProfile,
  bool setDefaultViewport = true,
}) async {
  if (setDefaultViewport) {
    await _setViewport(tester, const Size(900, 1400));
  }
  await tester.pumpWidget(
    localizedTestApp(
      home: MetabolicProfileScreen(
        now: () => _now,
        loadHistory: loadHistory,
        loadEffectiveProfile: loadEffectiveProfile ?? (_) async => _profile,
        createProfile: createProfile,
        updateProfile: updateProfile,
        deleteProfile: deleteProfile,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

MetabolicProfileHistoryEntry _entry({
  required int id,
  required DateTime date,
  required MetabolicProfile profile,
}) {
  return MetabolicProfileHistoryEntry(
    id: id,
    profileDate: date,
    profile: profile,
    createdAtIso: '2026-01-01T00:00:00.000',
  );
}
