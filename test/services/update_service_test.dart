import 'dart:async';
import 'dart:convert';

import 'package:calorie_tracker/services/update_coordinator.dart';
import 'package:calorie_tracker/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/http_fixture.dart';

void main() {
  group('UpdateService', () {
    test('uses injected endpoint, headers, and selects the first APK',
        () async {
      final endpoint = Uri.parse('https://updates.example.test/latest');
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(readFixture('github/newer_release.json'), 200);
      });
      addTearDown(client.close);

      final result = await UpdateService(
        client: client,
        endpoint: endpoint,
        timeout: Duration.zero,
      ).checkForUpdate(currentVersion: '1.8.2');

      expect(capturedRequest.url, endpoint);
      expect(capturedRequest.headers['Accept'], 'application/vnd.github+json');
      expect(capturedRequest.headers['User-Agent'], 'CalorieTracker-App');
      expect(result.currentVersion, '1.8.2');
      expect(result.latestVersion, '2.0.0');
      expect(result.updateAvailable, isTrue);
      expect(
        result.downloadUrl,
        'https://example.test/CalorieTracker-v2.0.0.apk',
      );
      expect(result.releaseUrl, 'https://example.test/releases/v2.0.0');
      expect(result.releaseNotes, 'Synthetic release notes.');
    });

    for (final scenario in [
      (
        current: '1.2.3',
        latest: '1.2.4',
        expected: true,
        name: 'newer patch',
      ),
      (
        current: '1.2.3',
        latest: '1.2.3',
        expected: false,
        name: 'equal version',
      ),
      (
        current: '1.2.3',
        latest: '1.2.2',
        expected: false,
        name: 'older patch',
      ),
      (
        current: 'v1.2.3',
        latest: 'v1.3.0',
        expected: true,
        name: 'optional v prefixes',
      ),
      (
        current: '1.2',
        latest: '1.2.1',
        expected: true,
        name: 'additional nonzero component',
      ),
      (
        current: '1.2.0',
        latest: '1.2',
        expected: false,
        name: 'missing components treated as zero',
      ),
      (
        current: '1.2.3',
        latest: '1.2.3-beta.1',
        expected: false,
        name: 'suffix ignored when numeric components match',
      ),
      (
        current: '1.2.3',
        latest: '1.2.4-beta.1',
        expected: true,
        name: 'suffix ignored after a newer numeric component',
      ),
    ]) {
      test('compares ${scenario.name}', () async {
        final result = await _checkVersion(
          current: scenario.current,
          latest: scenario.latest,
        );

        expect(result.updateAvailable, scenario.expected);
      });
    }

    test('returns no download URL when a release has no APK', () async {
      final client = MockClient(
        (_) async => http.Response(
          readFixture('github/release_without_apk.json'),
          200,
        ),
      );
      addTearDown(client.close);

      final result = await UpdateService(client: client).checkForUpdate(
        currentVersion: '1.0.0',
      );

      expect(result.updateAvailable, isTrue);
      expect(result.downloadUrl, isNull);
    });

    test('rejects missing tags', () async {
      await _expectPayloadFailure(
        jsonEncode({'assets': []}),
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('tag is missing'),
        ),
      );
    });

    test('rejects malformed JSON and non-object payloads', () async {
      await _expectPayloadFailure('{', isA<FormatException>());
      await _expectPayloadFailure('[]', isA<FormatException>());
    });

    test('rejects malformed assets', () async {
      await _expectPayloadFailure(
        jsonEncode({'tag_name': 'v2.0.0', 'assets': {}}),
        isA<FormatException>(),
      );
      await _expectPayloadFailure(
        jsonEncode({
          'tag_name': 'v2.0.0',
          'assets': ['not-an-object'],
        }),
        isA<FormatException>(),
      );
      await _expectPayloadFailure(
        jsonEncode({
          'tag_name': 'v2.0.0',
          'assets': [
            {'name': 'release.apk', 'browser_download_url': 123},
          ],
        }),
        isA<FormatException>(),
      );
    });

    test('surfaces HTTP failures', () async {
      final client = MockClient(
        (_) async => http.Response('synthetic failure', 503),
      );
      addTearDown(client.close);

      await expectLater(
        UpdateService(client: client).checkForUpdate(currentVersion: '1.0.0'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('503 synthetic failure'),
          ),
        ),
      );
    });

    test('times out without a live request or real delay', () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      addTearDown(client.close);

      await expectLater(
        UpdateService(
          client: client,
          timeout: Duration.zero,
        ).checkForUpdate(currentVersion: '1.0.0'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });
  });

  group('UpdateCoordinator', () {
    test('caches by installed version and force refresh bypasses cache',
        () async {
      final service = _FakeUpdateService();
      final coordinator = UpdateCoordinator(service: service);

      final first = await coordinator.checkForUpdates(currentVersion: '1.0.0');
      final cached = await coordinator.checkForUpdates(currentVersion: '1.0.0');
      final refreshed = await coordinator.checkForUpdates(
        currentVersion: '1.0.0',
        forceRefresh: true,
      );

      expect(identical(first, cached), isTrue);
      expect(service.calls, ['1.0.0', '1.0.0']);
      expect(refreshed.latestVersion, '2.0.2');
      expect(coordinator.latestResult, same(refreshed));
    });

    test('installed-version changes bypass the previous cache', () async {
      final service = _FakeUpdateService();
      final coordinator = UpdateCoordinator(service: service);

      await coordinator.checkForUpdates(currentVersion: '1.0.0');
      await coordinator.checkForUpdates(currentVersion: '1.1.0');

      expect(service.calls, ['1.0.0', '1.1.0']);
    });

    test('deduplicates concurrent requests for the same version', () async {
      final completer = Completer<UpdateCheckResult>();
      final service = _FakeUpdateService(handler: (_) => completer.future);
      final coordinator = UpdateCoordinator(service: service);

      final first = coordinator.checkForUpdates(currentVersion: '1.0.0');
      final second = coordinator.checkForUpdates(currentVersion: '1.0.0');
      expect(service.calls, ['1.0.0']);

      completer.complete(_result(current: '1.0.0', latest: '2.0.0'));
      expect(await first, same(await second));
    });

    test('does not share in-flight results between installed versions',
        () async {
      final completers = <String, Completer<UpdateCheckResult>>{};
      final service = _FakeUpdateService(
        handler: (version) =>
            (completers[version] ??= Completer<UpdateCheckResult>()).future,
      );
      final coordinator = UpdateCoordinator(service: service);

      final first = coordinator.checkForUpdates(currentVersion: '1.0.0');
      final second = coordinator.checkForUpdates(currentVersion: '1.1.0');
      expect(service.calls, ['1.0.0', '1.1.0']);

      completers['1.0.0']!.complete(
        _result(current: '1.0.0', latest: '2.0.0'),
      );
      completers['1.1.0']!.complete(
        _result(current: '1.1.0', latest: '2.0.0'),
      );
      expect((await first).currentVersion, '1.0.0');
      expect((await second).currentVersion, '1.1.0');
    });

    test('clears a failed in-flight request so a retry can succeed', () async {
      var shouldFail = true;
      final service = _FakeUpdateService(
        handler: (version) {
          if (shouldFail) {
            shouldFail = false;
            return Future.error(StateError('synthetic failure'));
          }
          return Future.value(_result(current: version, latest: '2.0.0'));
        },
      );
      final coordinator = UpdateCoordinator(service: service);

      await expectLater(
        coordinator.checkForUpdates(currentVersion: '1.0.0'),
        throwsStateError,
      );
      final result = await coordinator.checkForUpdates(currentVersion: '1.0.0');

      expect(result.latestVersion, '2.0.0');
      expect(service.calls, ['1.0.0', '1.0.0']);
    });
  });
}

Future<UpdateCheckResult> _checkVersion({
  required String current,
  required String latest,
}) async {
  final client = MockClient(
    (_) async => http.Response(
      jsonEncode({'tag_name': latest, 'assets': []}),
      200,
    ),
  );
  addTearDown(client.close);
  return UpdateService(client: client).checkForUpdate(currentVersion: current);
}

Future<void> _expectPayloadFailure(
  String body,
  Matcher matcher,
) async {
  final client = MockClient((_) async => http.Response(body, 200));
  addTearDown(client.close);
  await expectLater(
    UpdateService(client: client).checkForUpdate(currentVersion: '1.0.0'),
    throwsA(matcher),
  );
}

UpdateCheckResult _result({
  required String current,
  required String latest,
}) {
  return UpdateCheckResult(
    currentVersion: current,
    latestVersion: latest,
    updateAvailable: current != latest,
    downloadUrl: null,
    releaseUrl: null,
    releaseNotes: null,
  );
}

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService({
    Future<UpdateCheckResult> Function(String version)? handler,
  }) : _handler = handler;

  final Future<UpdateCheckResult> Function(String version)? _handler;
  final List<String> calls = [];

  @override
  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
  }) {
    calls.add(currentVersion);
    final handler = _handler;
    if (handler != null) {
      return handler(currentVersion);
    }
    return Future.value(
      _result(
        current: currentVersion,
        latest: '2.0.${calls.length}',
      ),
    );
  }
}
