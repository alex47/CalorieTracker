import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/day_summary.dart';
import '../models/daily_targets.dart';
import '../models/food_item.dart';
import '../models/metabolic_profile.dart';
import '../services/day_summary_service.dart';
import '../services/entries_repository.dart';
import '../services/macro_ratio_preset_catalog.dart';
import '../services/metabolic_profile_history_service.dart';
import '../services/nutrition_target_service.dart';
import '../services/openai_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../utils/error_localizer.dart';
import '../widgets/app_dialog.dart';
import '../widgets/dialog_action_row.dart';

class DaySummaryScreen extends StatefulWidget {
  const DaySummaryScreen({
    super.key,
    required this.date,
  });

  final DateTime date;

  @override
  State<DaySummaryScreen> createState() => _DaySummaryScreenState();
}

class _DaySummaryScreenState extends State<DaySummaryScreen> {
  bool _loading = true;
  bool _summarizing = false;
  String? _loadError;
  DaySummary? _summary;
  List<FoodItem> _items = const <FoodItem>[];
  String? _sourceHash;
  Map<String, dynamic>? _snapshot;

  DateTime get _dayOnlyDate => DateTime(widget.date.year, widget.date.month, widget.date.day);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final date = _dayOnlyDate;
      final settings = SettingsService.instance.settings;
      final items = await EntriesRepository.instance.fetchItemsForDate(date);
      final profile = await MetabolicProfileHistoryService.instance.getEffectiveProfileForDate(
        date: date,
      );
      final targets = profile == null ? null : NutritionTargetService.targetsFromProfile(profile);
      final snapshot = _buildSummarySnapshot(
        date: date,
        items: items,
        profile: profile,
        targets: targets,
        languageCode: settings.languageCode,
      );
      final sourceHash = DaySummaryService.instance.computeSourceHash(snapshot);
      final stored = await DaySummaryService.instance.fetchForDate(date);
      final matchesCurrentState = stored != null &&
          stored.sourceHash == sourceHash &&
          stored.languageCode == settings.languageCode;
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _snapshot = snapshot;
        _sourceHash = sourceHash;
        _summary = matchesCurrentState ? stored!.summary : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _summarize() async {
    final l10n = AppLocalizations.of(context)!;
    final apiKey = await SettingsService.instance.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setApiKeyInSettings)),
      );
      return;
    }
    if (_items.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noEntriesForDaySummary)),
      );
      return;
    }
    if (_snapshot == null || _sourceHash == null) {
      await _loadData();
      if (_snapshot == null || _sourceHash == null) {
        return;
      }
    }
    final settings = SettingsService.instance.settings;
    setState(() => _summarizing = true);
    try {
      final openAi = OpenAIService(
        apiKey,
        requestTimeout: Duration(seconds: settings.openAiTimeoutSeconds),
      );
      final summary = await openAi.summarizeDay(
        model: settings.model,
        languageCode: settings.languageCode,
        reasoningEffort: settings.reasoningEffort,
        maxOutputTokens: settings.maxOutputTokens,
        daySnapshot: _snapshot!,
      );
      await DaySummaryService.instance.upsert(
        date: _dayOnlyDate,
        languageCode: settings.languageCode,
        model: settings.model,
        sourceHash: _sourceHash!,
        summary: summary,
      );
      if (!mounted) {
        return;
      }
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToSummarizeDay(localizeError(error, l10n)))),
      );
      final raw = error is AiParseException ? error.rawResponseText : null;
      if (raw != null && raw.trim().isNotEmpty) {
        await _showRawResponse(raw);
      }
    } finally {
      if (mounted) {
        setState(() => _summarizing = false);
      }
    }
  }

  Future<void> _showRawResponse(String raw) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text(l10n.aiResponseDialogTitle),
        content: SizedBox(
          width: UiConstants.reestimateDialogWidth,
          child: SingleChildScrollView(child: SelectableText(raw)),
        ),
        actionItems: [
          DialogActionItem(
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              label: Text(l10n.acceptButton, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildSummarySnapshot({
    required DateTime date,
    required List<FoodItem> items,
    required MetabolicProfile? profile,
    required DailyTargets? targets,
    required String languageCode,
  }) {
    final sortedItems = [...items]..sort((a, b) => a.id.compareTo(b.id));
    final calories = sortedItems.fold<int>(0, (sum, item) => sum + item.calories);
    final fat = sortedItems.fold<double>(0, (sum, item) => sum + item.fat);
    final protein = sortedItems.fold<double>(0, (sum, item) => sum + item.protein);
    final carbs = sortedItems.fold<double>(0, (sum, item) => sum + item.carbs);
    final summaryDateKey = DaySummaryService.instance.dayKey(date);
    final macroPresetKey = profile == null
        ? null
        : MacroRatioPresetCatalog.keyForRatios(
            fatPercent: profile.fatRatioPercent,
            proteinPercent: profile.proteinRatioPercent,
            carbsPercent: profile.carbsRatioPercent,
          );
    return {
      'date': summaryDateKey,
      'language_code': languageCode,
      'entries': sortedItems
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'amount': item.amount,
              'calories': item.calories,
              'fat': item.fat,
              'protein': item.protein,
              'carbs': item.carbs,
              'notes': item.notes,
            },
          )
          .toList(growable: false),
      'totals': {
        'calories': calories,
        'fat': fat,
        'protein': protein,
        'carbs': carbs,
      },
      'metabolic_profile': profile == null
          ? null
          : {
              'macro_preset_key': macroPresetKey,
              'age': profile.age,
              'sex': profile.sex,
              'height_cm': profile.heightCm,
              'weight_kg': profile.weightKg,
              'activity_level': profile.activityLevel,
              'macro_preset_name': MacroRatioPresetCatalog.localizedLabelForLanguageCode(
                languageCode: languageCode,
                key: macroPresetKey!,
              ),
              'fat_ratio_percent': profile.fatRatioPercent,
              'protein_ratio_percent': profile.proteinRatioPercent,
              'carbs_ratio_percent': profile.carbsRatioPercent,
            },
      'targets': targets == null
          ? null
          : {
              'calories': targets.calories,
              'fat': targets.fat,
              'protein': targets.protein,
              'carbs': targets.carbs,
            },
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined),
            const SizedBox(width: UiConstants.appBarIconTextSpacing),
            Text(l10n.dailySummaryTitle),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(UiConstants.pagePadding),
              children: [
                if (_loadError != null)
                  Text(
                    _loadError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                else if (_summary == null)
                  Text(l10n.noDailySummaryYet)
                else ...[
                  _SummaryOverviewCard(
                    title: l10n.dailySummaryOverviewTitle,
                    text: _summary!.summary,
                  ),
                  const SizedBox(height: UiConstants.mediumSpacing),
                  _SummarySectionCard(
                    title: l10n.dailySummaryHighlightsTitle,
                    icon: Icons.check_circle_outline,
                    accentColor: AppColors.daySummaryHighlights,
                    items: _summary!.highlights,
                  ),
                  const SizedBox(height: UiConstants.mediumSpacing),
                  _SummarySectionCard(
                    title: l10n.dailySummaryIssuesTitle,
                    icon: Icons.error_outline,
                    accentColor: AppColors.daySummaryIssues,
                    items: _summary!.issues,
                  ),
                  const SizedBox(height: UiConstants.mediumSpacing),
                  _SummarySectionCard(
                    title: l10n.dailySummarySuggestionsTitle,
                    icon: Icons.lightbulb_outline,
                    accentColor: AppColors.daySummarySuggestions,
                    items: _summary!.suggestions,
                  ),
                ],
                const SizedBox(height: UiConstants.largeSpacing),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _summarizing || _items.isEmpty ? null : _summarize,
                    icon: _summarizing
                        ? const SizedBox(
                            height: UiConstants.loadingIndicatorSize,
                            width: UiConstants.loadingIndicatorSize,
                            child: CircularProgressIndicator(
                              strokeWidth: UiConstants.loadingIndicatorStrokeWidth,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      _summary == null ? l10n.summarizeDayButton : l10n.summarizeAgainButton,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryOverviewCard extends StatelessWidget {
  const _SummaryOverviewCard({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(UiConstants.mediumSpacing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.summarize_outlined, color: AppColors.calories, size: 18),
                      const SizedBox(width: UiConstants.smallSpacing),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.calories,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: UiConstants.smallSpacing),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySectionCard extends StatelessWidget {
  const _SummarySectionCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(color: accentColor);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
        border: Border.all(color: accentColor.withValues(alpha: 0.7)),
        color: AppColors.boxBackground,
      ),
      padding: const EdgeInsets.all(UiConstants.mediumSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: UiConstants.smallSpacing),
              Text(title, style: titleStyle),
            ],
          ),
          const SizedBox(height: UiConstants.smallSpacing),
          if (items.isEmpty)
            Text(
              '-',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: UiConstants.xxSmallSpacing),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: accentColor)),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
