import 'dart:async';

import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:calorie_tracker/models/app_settings.dart';
import 'package:calorie_tracker/screens/settings_screen.dart';
import 'package:calorie_tracker/widgets/labeled_input_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('flushes a pending edit before leaving settings', (tester) async {
    AppSettings? savedSettings;
    await _openSettings(
      tester,
      SettingsScreen(
        loadApiKey: () async => null,
        saveSettings: (settings) async {
          savedSettings = settings;
        },
        autosaveDebounce: const Duration(days: 1),
      ),
    );

    await tester.enterText(
      _textFieldForLabel('Max output tokens'),
      '1234',
    );
    expect(savedSettings, isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(savedSettings?.maxOutputTokens, 1234);
    expect(find.text('Open screen'), findsOneWidget);
  });

  testWidgets('waits for a pending save before starting import',
      (tester) async {
    final saveCompleter = Completer<void>();
    final savedSettings = <AppSettings>[];
    var pickerCalls = 0;
    await _openSettings(
      tester,
      SettingsScreen(
        loadApiKey: () async => null,
        saveSettings: (settings) {
          savedSettings.add(settings);
          return saveCompleter.future;
        },
        pickImportData: () async {
          pickerCalls += 1;
          return null;
        },
        autosaveDebounce: const Duration(days: 1),
      ),
    );

    await tester.enterText(
      _textFieldForLabel('Max output tokens'),
      '2345',
    );
    await _tapVisible(tester, find.text('Import data'));

    expect(savedSettings, hasLength(1));
    expect(savedSettings.single.maxOutputTokens, 2345);
    expect(pickerCalls, 0);

    await tester.pump(const Duration(days: 2));
    expect(savedSettings, hasLength(1));
    expect(pickerCalls, 0);

    saveCompleter.complete();
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
    expect(savedSettings, hasLength(1));
  });

  testWidgets('keeps a failed pending edit available for retry',
      (tester) async {
    var saveAttempts = 0;
    await _openSettings(
      tester,
      SettingsScreen(
        loadApiKey: () async => null,
        saveSettings: (settings) async {
          saveAttempts += 1;
          if (saveAttempts == 1) {
            throw StateError('storage unavailable');
          }
        },
        autosaveDebounce: const Duration(days: 1),
      ),
    );

    await tester.enterText(
      _textFieldForLabel('Max output tokens'),
      '3456',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(saveAttempts, 1);
    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.text('Failed to save settings: storage unavailable'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(saveAttempts, 2);
    expect(find.text('Open screen'), findsOneWidget);
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

Future<void> _openSettings(
  WidgetTester tester,
  SettingsScreen screen,
) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_testApp(screen));
  await tester.tap(find.text('Open screen'));
  await tester.pumpAndSettle();
}

Finder _textFieldForLabel(String label) {
  return find.descendant(
    of: find.widgetWithText(LabeledInputBox, label),
    matching: find.byType(TextField),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}
