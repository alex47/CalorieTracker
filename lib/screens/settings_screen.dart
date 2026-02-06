import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_settings.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  late String _selectedModel;
  bool _saving = false;
  bool _testing = false;
  bool _checkingUpdates = false;
  bool _installingUpdate = false;
  UpdateCheckResult? _updateResult;

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance.settings;
    _selectedModel = settings.model;
    _goalController.text = settings.dailyGoal.toString();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final apiKey = await SettingsService.instance.getApiKey();
    setState(() {
      _apiKeyController.text = apiKey ?? '';
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final dailyGoal = int.tryParse(_goalController.text.trim()) ?? 2000;
    await SettingsService.instance.setApiKey(_apiKeyController.text.trim());
    await SettingsService.instance.updateSettings(
      AppSettings(model: _selectedModel, dailyGoal: dailyGoal),
    );
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
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

  Future<void> _testKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key first.')),
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final service = OpenAIService(apiKey);
      await service.testConnection(model: _selectedModel);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key test succeeded.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API key test failed: ${_displayError(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'OpenAI API key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving || _testing ? null : _testKey,
            child: _testing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test key'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedModel,
            decoration: const InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'gpt-5-mini',
                child: Text('GPT-5 mini (default)'),
              ),
              DropdownMenuItem(
                value: 'gpt-5.2',
                child: Text('GPT-5.2'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedModel = value);
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _goalController,
            decoration: const InputDecoration(
              labelText: 'Daily calorie goal',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving || _testing ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save settings'),
          ),
          const SizedBox(height: 24),
          Text(
            'App updates',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _checkingUpdates || _installingUpdate ? null : _checkForUpdates,
            child: _checkingUpdates
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Check for updates'),
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
                    : const Text('Install latest APK'),
              ),
            ],
          ],
          const SizedBox(height: 24),
          Text(
            'Data tools',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export is coming soon.')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Export data'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import is coming soon.')),
              );
            },
            icon: const Icon(Icons.upload),
            label: const Text('Import data'),
          ),
        ],
      ),
    );
  }
}
