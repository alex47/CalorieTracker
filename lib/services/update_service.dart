import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/app_defaults.dart';

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.releaseNotes,
  });

  final String currentVersion;
  final String latestVersion;
  final bool updateAvailable;
  final String? downloadUrl;
  final String? releaseUrl;
  final String? releaseNotes;
}

class UpdateService {
  UpdateService({
    http.Client? client,
    Uri? endpoint,
    Duration? timeout,
  })  : _client = client,
        endpoint = endpoint ?? Uri.parse(_latestReleaseUrl),
        requestTimeout = timeout ?? AppDefaults.updateRequestTimeout;

  static const String _latestReleaseUrl =
      'https://api.github.com/repos/alex47/CalorieTracker/releases/latest';

  final http.Client? _client;
  final Uri endpoint;
  final Duration requestTimeout;

  Future<http.Response> _get(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _client?.get(url, headers: headers) ??
        http.get(url, headers: headers);
  }

  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
  }) async {
    final response = await _get(
      endpoint,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'CalorieTracker-App',
      },
    ).timeout(requestTimeout, onTimeout: () {
      throw StateError('Update check timed out.');
    });

    if (response.statusCode >= 400) {
      throw StateError(
          'Update check failed: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Latest release response must be an object.');
    }
    final payload = decoded;
    final latestTag = (payload['tag_name'] as String? ?? '').trim();
    if (latestTag.isEmpty) {
      throw const FormatException('Latest release tag is missing.');
    }

    final latestVersion = _normalizeVersion(latestTag);
    final normalizedCurrent = _normalizeVersion(currentVersion);
    final updateAvailable = _isNewerVersion(
      current: normalizedCurrent,
      latest: latestVersion,
    );

    final rawAssets = payload['assets'];
    if (rawAssets != null && rawAssets is! List) {
      throw const FormatException('Latest release assets must be a list.');
    }
    final assets = rawAssets as List<dynamic>? ?? const [];
    String? apkUrl;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) {
        throw const FormatException('Latest release asset must be an object.');
      }
      final map = asset;
      final name = (map['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        final rawUrl = map['browser_download_url'];
        if (rawUrl != null && rawUrl is! String) {
          throw const FormatException(
            'APK browser download URL must be a string.',
          );
        }
        apkUrl = rawUrl as String?;
        break;
      }
    }

    return UpdateCheckResult(
      currentVersion: normalizedCurrent,
      latestVersion: latestVersion,
      updateAvailable: updateAvailable,
      downloadUrl: apkUrl,
      releaseUrl: payload['html_url'] as String?,
      releaseNotes: payload['body'] as String?,
    );
  }

  String _normalizeVersion(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.startsWith('v')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  bool _isNewerVersion({
    required String current,
    required String latest,
  }) {
    final currentParts = _toNumericParts(current);
    final latestParts = _toNumericParts(latest);
    final length = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (var i = 0; i < length; i++) {
      final currentValue = i < currentParts.length ? currentParts[i] : 0;
      final latestValue = i < latestParts.length ? latestParts[i] : 0;
      if (latestValue > currentValue) {
        return true;
      }
      if (latestValue < currentValue) {
        return false;
      }
    }
    return false;
  }

  List<int> _toNumericParts(String version) {
    final numericCore = version.split(RegExp(r'[-+]')).first;
    return numericCore.split('.').map((part) {
      final digits = RegExp(r'^\d+').stringMatch(part);
      return int.tryParse(digits ?? '0') ?? 0;
    }).toList();
  }
}
