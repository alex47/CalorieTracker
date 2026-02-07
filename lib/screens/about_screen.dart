import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static const routeName = '/about';
  static const _repoUrl = 'https://github.com/alex47/CalorieTracker';

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _checkingUpdates = false;
  bool _installingUpdate = false;
  double? _downloadProgress;
  UpdateCheckResult? _updateResult;

  Future<void> _openRepo(BuildContext context) async {
    final uri = Uri.parse(AboutScreen._repoUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open GitHub link.')),
      );
    }
  }

  String _displayError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length).trim();
    }
    return raw;
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checkingUpdates = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final service = UpdateService();
      final result = await service.checkForUpdate(
        currentVersion: packageInfo.version,
      );
      if (mounted) {
        setState(() => _updateResult = result);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: ${_displayError(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdates = false);
      }
    }
  }

  Future<void> _downloadUpdate() async {
    final url = _updateResult?.downloadUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No APK asset found in latest release.')),
      );
      return;
    }

    if (!Platform.isAndroid) {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open update download URL.')),
        );
      }
      return;
    }

    setState(() {
      _installingUpdate = true;
      _downloadProgress = 0;
    });
    try {
      final client = HttpClient();
      final response = await client.getUrl(Uri.parse(url)).then((request) => request.close());
      if (response.statusCode >= 400) {
        client.close(force: true);
        throw StateError('APK download failed: HTTP ${response.statusCode}.');
      }
      final bytes = await _collectDownloadBytes(
        response,
        totalBytes: response.contentLength > 0 ? response.contentLength : null,
      );
      client.close(force: true);
      final fileName = p.basename(Uri.parse(url).path).isEmpty
          ? 'CalorieTracker-latest.apk'
          : p.basename(Uri.parse(url).path);
      await _writeDownloadedApkAndHandlePostAction(
        bytes: bytes,
        fileName: fileName,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update install failed: ${_displayError(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _installingUpdate = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<Uint8List> _collectDownloadBytes(
    Stream<List<int>> stream, {
    required int? totalBytes,
  }) async {
    final bytesBuilder = BytesBuilder(copy: false);
    var receivedBytes = 0;
    await for (final chunk in stream) {
      bytesBuilder.add(chunk);
      receivedBytes += chunk.length;
      if (mounted) {
        setState(() {
          _downloadProgress = totalBytes == null ? null : receivedBytes / totalBytes;
        });
      }
    }
    return bytesBuilder.takeBytes();
  }

  Future<void> _writeDownloadedApkAndHandlePostAction({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final apkFile = File(p.join(tempDir.path, fileName));
    await apkFile.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw StateError('Could not open installer: ${result.message}');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Installer opened. If prompted, allow installs from this app.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _checkingUpdates || _installingUpdate;
    return WillPopScope(
      onWillPop: () async => !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 8),
              Text('About'),
            ],
          ),
        ),
        body: AbsorbPointer(
          absorbing: isBusy,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '...';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  'Calorie Tracker helps you log meals and estimate calories using OpenAI.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Version: $version',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : _checkForUpdates,
                    icon: const Icon(Icons.update),
                    label: _checkingUpdates
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Check for updates', textAlign: TextAlign.center),
                    ),
                  ),
                if (_updateResult != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _updateResult!.updateAvailable
                        ? 'Update available: ${_updateResult!.latestVersion} (current: ${_updateResult!.currentVersion})'
                        : 'You are up to date (${_updateResult!.currentVersion}).',
                  ),
                  if (_updateResult!.updateAvailable) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isBusy ? null : _downloadUpdate,
                        icon: const Icon(Icons.system_update),
                        label: _installingUpdate
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Install latest APK', textAlign: TextAlign.center),
                      ),
                    ),
                    if (_installingUpdate) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _downloadProgress),
                      const SizedBox(height: 6),
                      Text(
                        _downloadProgress == null
                            ? 'Downloading update...'
                            : 'Downloading update... ${(_downloadProgress! * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ],
                const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : () => _openRepo(context),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('GitHub repository', textAlign: TextAlign.center),
                    ),
                  ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
