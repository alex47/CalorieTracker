import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_coordinator.dart';
import '../services/update_service.dart';
import '../theme/ui_constants.dart';
import '../utils/error_localizer.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({
    super.key,
    this.initialUpdateResult,
  });

  static const routeName = '/about';
  static const _repoUrl = 'https://github.com/alex47/CalorieTracker';
  final UpdateCheckResult? initialUpdateResult;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _checkingUpdates = false;
  bool _installingUpdate = false;
  double? _downloadProgress;
  UpdateCheckResult? _updateResult;
  late final Future<PackageInfo> _packageInfoFuture;
  HttpClient? _activeDownloadClient;
  bool _downloadCancelledByUser = false;

  @override
  void dispose() {
    _activeDownloadClient?.close(force: true);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _updateResult = widget.initialUpdateResult ?? UpdateCoordinator.instance.latestResult;
  }

  Future<void> _openRepo(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.parse(AboutScreen._repoUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.couldNotOpenGithubLink)),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _checkingUpdates = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final result = await UpdateCoordinator.instance.checkForUpdates(
        currentVersion: packageInfo.version,
        forceRefresh: true,
      );
      if (mounted) {
        setState(() => _updateResult = result);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.updateCheckFailed(localizeError(error, l10n)))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingUpdates = false);
      }
    }
  }

  Future<void> _downloadUpdate() async {
    final l10n = AppLocalizations.of(context)!;
    final url = _updateResult?.downloadUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noApkAssetFound)),
      );
      return;
    }

    if (!Platform.isAndroid) {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotOpenUpdateUrl)),
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
      _activeDownloadClient = client;
      _downloadCancelledByUser = false;
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
      if (_downloadCancelledByUser) {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.updateInstallFailed(localizeError(error, l10n)))),
        );
      }
    } finally {
      _activeDownloadClient = null;
      if (mounted) {
        setState(() {
          _installingUpdate = false;
          _downloadProgress = null;
          _downloadCancelledByUser = false;
        });
      }
    }
  }

  void _cancelDownload() {
    if (!_installingUpdate) {
      return;
    }
    _downloadCancelledByUser = true;
    _activeDownloadClient?.close(force: true);
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
    final l10n = AppLocalizations.of(context)!;
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
        SnackBar(content: Text(l10n.installerOpenedMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBusy = _checkingUpdates || _installingUpdate;
    return PopScope(
      canPop: !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: UiConstants.appBarIconTextSpacing),
              Text(l10n.aboutTitle),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(UiConstants.pagePadding),
          child: FutureBuilder<PackageInfo>(
            future: _packageInfoFuture,
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '...';
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  l10n.aboutDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: UiConstants.largeSpacing),
                Text(
                  l10n.versionLabel(version),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: UiConstants.buttonSpacing),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : () => _openRepo(context),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.githubRepositoryButton, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(height: UiConstants.buttonSpacing),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isBusy ? null : _checkForUpdates,
                    icon: const Icon(Icons.update),
                    label: _checkingUpdates
                        ? const SizedBox(
                            height: UiConstants.loadingIndicatorSize,
                            width: UiConstants.loadingIndicatorSize,
                            child: CircularProgressIndicator(strokeWidth: UiConstants.loadingIndicatorStrokeWidth),
                          )
                        : Text(l10n.checkForUpdatesButton, textAlign: TextAlign.center),
                    ),
                  ),
                if (_updateResult != null) ...[
                  const SizedBox(height: UiConstants.mediumSpacing),
                  Text(
                    _updateResult!.updateAvailable
                        ? l10n.updateAvailableStatus(
                            _updateResult!.latestVersion,
                          )
                        : l10n.upToDateStatus,
                  ),
                  if (_updateResult!.updateAvailable) ...[
                    const SizedBox(height: UiConstants.buttonSpacing),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isBusy ? null : _downloadUpdate,
                        icon: const Icon(Icons.system_update),
                        label: _installingUpdate
                            ? const SizedBox(
                                height: UiConstants.loadingIndicatorSize,
                                width: UiConstants.loadingIndicatorSize,
                                child: CircularProgressIndicator(strokeWidth: UiConstants.loadingIndicatorStrokeWidth),
                              )
                            : Text(l10n.installLatestApkButton, textAlign: TextAlign.center),
                      ),
                    ),
                    if (_installingUpdate) ...[
                      const SizedBox(height: UiConstants.buttonSpacing),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _cancelDownload,
                          icon: const Icon(Icons.close),
                          label: Text(l10n.cancelButton, textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                    if (_installingUpdate) ...[
                      const SizedBox(height: UiConstants.smallSpacing),
                      LinearProgressIndicator(value: _downloadProgress),
                      const SizedBox(height: UiConstants.xxSmallSpacing),
                      Text(
                        _downloadProgress == null
                            ? l10n.downloadingUpdate
                            : l10n.downloadingUpdateProgress(
                                (_downloadProgress! * 100).clamp(0, 100).toStringAsFixed(0),
                              ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ],
                  ],
              );
            },
          ),
        ),
      ),
    );
  }
}
