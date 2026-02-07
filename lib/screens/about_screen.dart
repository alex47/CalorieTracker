import 'dart:io';

import 'package:flutter/foundation.dart';
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

    setState(() => _installingUpdate = true);
    try {
      final client = HttpClient();
      final response = await client.getUrl(Uri.parse(url)).then((request) => request.close());
      if (response.statusCode >= 400) {
        client.close(force: true);
        throw StateError('APK download failed: HTTP ${response.statusCode}.');
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      client.close(force: true);
      final tempDir = await getTemporaryDirectory();
      final fileName = p.basename(Uri.parse(url).path).isEmpty
          ? 'CalorieTracker-latest.apk'
          : p.basename(Uri.parse(url).path);
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update install failed: ${_displayError(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _installingUpdate = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
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
                  child: FilledButton(
                    onPressed: _checkingUpdates || _installingUpdate ? null : _checkForUpdates,
                    child: _checkingUpdates
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
                    FilledButton.icon(
                      onPressed: _installingUpdate ? null : _downloadUpdate,
                      icon: const Icon(Icons.system_update),
                      label: _installingUpdate
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Install latest APK', textAlign: TextAlign.center),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openRepo(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('GitHub repository', textAlign: TextAlign.center),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
