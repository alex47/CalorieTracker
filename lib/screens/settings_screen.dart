import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';

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
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedModel,
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
          ElevatedButton(
            onPressed: _saving ? null : _save,
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
            'Data tools',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export is coming soon.')),
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Export data'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
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
