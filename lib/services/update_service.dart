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
  static const String _latestReleaseUrl =
      'https://api.github.com/repos/alex47/CalorieTracker/releases/latest';
  static const Duration requestTimeout = AppDefaults.updateRequestTimeout;

  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
  }) async {
    final response = await http
        .get(
          Uri.parse(_latestReleaseUrl),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'CalorieTracker-App',
          },
        )
        .timeout(requestTimeout, onTimeout: () {
          throw StateError('Update check timed out.');
        });

    if (response.statusCode >= 400) {
      throw StateError('Update check failed: ${response.statusCode} ${response.body}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
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

    final assets = payload['assets'] as List<dynamic>? ?? const [];
    String? apkUrl;
    for (final asset in assets) {
      final map = asset as Map<String, dynamic>;
      final name = (map['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = map['browser_download_url'] as String?;
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
    return version.split('.').map((part) {
      final digits = RegExp(r'^\d+').stringMatch(part);
      return int.tryParse(digits ?? '0') ?? 0;
    }).toList();
  }
}
