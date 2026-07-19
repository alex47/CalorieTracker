import 'dart:async';

import 'package:calorie_tracker/screens/about_screen.dart';
import 'package:calorie_tracker/screens/settings_screen.dart';
import 'package:calorie_tracker/services/update_service.dart';
import 'package:calorie_tracker/widgets/labeled_dropdown_box.dart';
import 'package:calorie_tracker/widgets/labeled_input_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/localized_test_app.dart';

void main() {
  group('SettingsScreen external operations', () {
    testWidgets('loads models offline and disables the dropdown while waiting',
        (tester) async {
      final models = Completer<List<String>>();
      String? loadedWithKey;
      await _pumpSettings(
        tester,
        SettingsScreen(
          loadApiKey: () async => 'dummy-key',
          loadModels: (apiKey) {
            loadedWithKey = apiKey;
            return models.future;
          },
          saveSettings: (_) async {},
        ),
        settle: false,
      );
      await tester.pump();

      expect(loadedWithKey, 'dummy-key');
      var modelDropdown = _dropdown('Model');
      expect(modelDropdown.enabled, isFalse);
      expect(modelDropdown.trailing, isA<SizedBox>());

      models.complete(['gpt-offline-a', 'gpt-offline-b']);
      await tester.pumpAndSettle();

      modelDropdown = _dropdown('Model');
      expect(modelDropdown.enabled, isTrue);
      expect(modelDropdown.items.map((item) => item.value), [
        'gpt-offline-a',
        'gpt-offline-b',
      ]);
      expect(find.text('gpt-offline-a'), findsOneWidget);
    });

    testWidgets('tests and saves a key with a visible busy state',
        (tester) async {
      final connection = Completer<void>();
      String? testedKey;
      String? testedModel;
      String? savedKey;
      await _pumpSettings(
        tester,
        SettingsScreen(
          loadApiKey: () async => null,
          loadModels: (_) async => ['gpt-offline'],
          testConnection: ({required apiKey, required model}) {
            testedKey = apiKey;
            testedModel = model;
            return connection.future;
          },
          saveApiKey: (apiKey) async => savedKey = apiKey,
          saveSettings: (_) async {},
        ),
      );

      await tester.enterText(_input('OpenAI API key'), '  dummy-key  ');
      await tester.tap(find.text('Test key'));
      await tester.pump();

      expect(testedKey, 'dummy-key');
      expect(testedModel, isNotEmpty);
      expect(_button('Test key').onPressed, isNull);
      expect(
        find.descendant(
          of: _buttonFinder('Test key'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      connection.complete();
      await tester.pumpAndSettle();
      expect(savedKey, 'dummy-key');
      expect(find.text('API key test succeeded. Key saved.'), findsOneWidget);
      expect(_dropdown('Model').items.single.value, 'gpt-offline');
    });

    testWidgets('requires a key before testing', (tester) async {
      await _pumpSettings(
        tester,
        SettingsScreen(
          loadApiKey: () async => null,
          saveSettings: (_) async {},
        ),
      );

      await tester.tap(find.text('Test key'));
      await tester.pump();
      expect(find.text('Please enter an API key first.'), findsOneWidget);
    });

    testWidgets('reports connection failures without saving', (tester) async {
      var saveCalls = 0;
      await _pumpSettings(
        tester,
        SettingsScreen(
          loadApiKey: () async => null,
          loadModels: (_) async => ['gpt-offline'],
          testConnection: ({required apiKey, required model}) async {
            throw StateError('connection failed');
          },
          saveApiKey: (_) async => saveCalls += 1,
          saveSettings: (_) async {},
        ),
      );

      await tester.enterText(_input('OpenAI API key'), 'dummy-key');
      await tester.tap(find.text('Test key'));
      await tester.pumpAndSettle();
      expect(find.textContaining('API key test failed:'), findsOneWidget);
      expect(find.textContaining('connection failed'), findsOneWidget);
      expect(saveCalls, 0);
      expect(_button('Test key').onPressed, isNotNull);
    });
  });

  group('AboutScreen', () {
    testWidgets('renders package information and an up-to-date state',
        (tester) async {
      await _pumpAbout(
        tester,
        AboutScreen(
          loadPackageInfo: _packageInfo,
          initialUpdateResult: _result(
            current: '1.8.2',
            latest: '1.8.2',
            available: false,
          ),
        ),
      );

      expect(find.text('Version: 1.8.2'), findsOneWidget);
      expect(find.text('You are up to date.'), findsOneWidget);
      expect(find.text('Install latest APK'), findsNothing);
    });

    testWidgets('checks updates busy and opens repository and download links',
        (tester) async {
      final update = Completer<UpdateCheckResult>();
      final openedUris = <Uri>[];
      String? checkedVersion;
      await _pumpAbout(
        tester,
        AboutScreen(
          loadPackageInfo: _packageInfo,
          checkForUpdates: (currentVersion) {
            checkedVersion = currentVersion;
            return update.future;
          },
          openExternalUrl: (uri) async {
            openedUris.add(uri);
            return true;
          },
        ),
      );

      await tester.tap(find.text('Check for updates'));
      await tester.pump();
      expect(checkedVersion, '1.8.2');
      expect(_button('Check for updates').onPressed, isNull);
      expect(
        find.descendant(
          of: _buttonFinder('Check for updates'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      update.complete(
        _result(
          current: '1.8.2',
          latest: '1.8.3',
          available: true,
          downloadUrl: 'https://example.test/app.apk',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New version available: 1.8.3'), findsOneWidget);

      await tester.tap(find.text('GitHub repository'));
      await tester.pump();
      await tester.tap(find.text('Install latest APK'));
      await tester.pump();
      expect(openedUris.map((uri) => uri.toString()), [
        'https://github.com/alex47/CalorieTracker',
        'https://example.test/app.apk',
      ]);
    });

    testWidgets('reports repository launch failures', (tester) async {
      await _pumpAbout(
        tester,
        AboutScreen(
          loadPackageInfo: _packageInfo,
          openExternalUrl: (_) async => false,
        ),
      );

      await tester.tap(find.text('GitHub repository'));
      await tester.pump();
      expect(find.text('Could not open GitHub link.'), findsOneWidget);
    });

    testWidgets('reports an available release without an APK', (tester) async {
      await _pumpAbout(
        tester,
        AboutScreen(
          loadPackageInfo: _packageInfo,
          initialUpdateResult: _result(
            current: '1.8.2',
            latest: '1.8.3',
            available: true,
          ),
        ),
      );

      await tester.tap(find.text('Install latest APK'));
      await tester.pump();
      expect(
          find.text('No APK asset found in latest release.'), findsOneWidget);
    });

    testWidgets('reports update-check failures and re-enables checking',
        (tester) async {
      await _pumpAbout(
        tester,
        AboutScreen(
          loadPackageInfo: _packageInfo,
          checkForUpdates: (_) async {
            throw StateError('update failed');
          },
        ),
      );

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Update check failed:'), findsOneWidget);
      expect(find.textContaining('update failed'), findsOneWidget);
      expect(_button('Check for updates').onPressed, isNotNull);
    });
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  SettingsScreen screen, {
  bool settle = true,
}) async {
  await _setViewport(tester);
  await tester.pumpWidget(localizedTestApp(home: screen));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _pumpAbout(
  WidgetTester tester,
  AboutScreen screen,
) async {
  await _setViewport(tester);
  await tester.pumpWidget(localizedTestApp(home: screen));
  await tester.pumpAndSettle();
}

Future<void> _setViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _input(String label) {
  return find.descendant(
    of: find.widgetWithText(LabeledInputBox, label),
    matching: find.byType(TextField),
  );
}

LabeledDropdownBox<String> _dropdown(String label) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is LabeledDropdownBox<String> && widget.label == label,
  );
  return finder.evaluate().single.widget as LabeledDropdownBox<String>;
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

Future<PackageInfo> _packageInfo() async {
  return PackageInfo(
    appName: 'Calorie Tracker',
    packageName: 'com.example.calorie_tracker',
    version: '1.8.2',
    buildNumber: '1',
  );
}

UpdateCheckResult _result({
  required String current,
  required String latest,
  required bool available,
  String? downloadUrl,
}) {
  return UpdateCheckResult(
    currentVersion: current,
    latestVersion: latest,
    updateAvailable: available,
    downloadUrl: downloadUrl,
    releaseUrl: 'https://example.test/release',
    releaseNotes: 'Synthetic release',
  );
}
