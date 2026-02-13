import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/daily_targets.dart';
import '../models/food_item.dart';
import '../models/metric_type.dart';
import '../services/entries_repository.dart';
import '../services/metabolic_profile_history_service.dart';
import '../services/nutrition_target_service.dart';
import '../services/settings_service.dart';
import '../theme/ui_constants.dart';
import '../widgets/food_table_card.dart';
import '../widgets/labeled_progress_bar.dart';
import '../main.dart';
import 'food_item_detail_screen.dart';

class DailyMetricDetailScreen extends StatefulWidget {
  const DailyMetricDetailScreen({
    super.key,
    required this.date,
    required this.metricType,
  });

  final DateTime date;
  final MetricType metricType;

  @override
  State<DailyMetricDetailScreen> createState() => _DailyMetricDetailScreenState();
}

class _DailyMetricDetailScreenState extends State<DailyMetricDetailScreen> with RouteAware {
  late Future<List<FoodItem>> _itemsFuture;
  late Future<DailyTargets?> _targetsFuture;
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _itemsFuture = EntriesRepository.instance.fetchItemsForDate(widget.date);
    _targetsFuture = _loadTargets();
  }

  void _reload() {
    setState(() {
      _itemsFuture = EntriesRepository.instance.fetchItemsForDate(widget.date);
      _targetsFuture = _loadTargets();
    });
  }

  Future<DailyTargets?> _loadTargets() async {
    final profile = await MetabolicProfileHistoryService.instance.getEffectiveProfileForDate(
      date: widget.date,
    );
    if (profile == null) {
      return null;
    }
    return NutritionTargetService.targetsFromProfile(profile);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      if (_route != null) {
        routeObserver.unsubscribe(this);
      }
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    if (_route != null) {
      routeObserver.unsubscribe(this);
      _route = null;
    }
    super.dispose();
  }

  @override
  void didPopNext() {
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final metricLabel = widget.metricType.label(l10n);
    final metricUnit = widget.metricType.unit;
    final metricColor = widget.metricType.color;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pie_chart_outline),
            const SizedBox(width: UiConstants.appBarIconTextSpacing),
            Text(metricLabel),
          ],
        ),
      ),
      body: FutureBuilder<List<FoodItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(UiConstants.pagePadding),
              child: Text(
                l10n.failedToLoadEntries,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          final items = snapshot.data ?? const <FoodItem>[];
          final total = items.fold<double>(
            0,
            (sum, item) => sum + widget.metricType.valueFromFoodItem(item),
          );

          final contributors = items
              .map(
                (item) => _MetricContribution(
                  item: item,
                  value: widget.metricType.valueFromFoodItem(item),
                ),
              )
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return FutureBuilder<DailyTargets?>(
            future: _targetsFuture,
            builder: (context, targetSnapshot) {
              if (targetSnapshot.connectionState == ConnectionState.waiting &&
                  !targetSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final targets = targetSnapshot.data;
              final metricGoal = targets == null
                  ? null
                  : widget.metricType.goalFromDailyTargets(targets);
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: UiConstants.largeSpacing),
                children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiConstants.smallSpacing,
                      vertical: UiConstants.xxSmallSpacing,
                    ),
                    child: Text(
                      formatDate(
                        widget.date,
                        languageCode: SettingsService.instance.settings.languageCode,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: UiConstants.mediumSpacing),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                child: metricGoal == null
                    ? Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(UiConstants.mediumSpacing),
                          child: Text(l10n.setMetabolicProfileHint),
                        ),
                      )
                    : LabeledProgressBar(
                        label: metricLabel,
                        value: total,
                        goal: metricGoal,
                        unit: metricUnit,
                        color: metricColor,
                      ),
              ),
              const SizedBox(height: UiConstants.largeSpacing),
              if (contributors.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                  child: Text(l10n.emptyEntriesHint),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                  child: FoodTableCard(
                    highlightRowsByDominantMacro: true,
                    columns: buildStandardFoodTableColumns(
                      firstLabel: l10n.foodLabel,
                      secondLabel: metricLabel,
                      thirdLabel: '%',
                    ),
                    rows: contributors.map((entry) {
                      final percent = total > 0 ? (entry.value / total) * 100 : 0.0;
                      return FoodTableRowData(
                        onTap: () async {
                          final result = await Navigator.push<dynamic>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FoodItemDetailScreen(item: entry.item, itemDate: widget.date),
                            ),
                          );
                          if (result == true || (result is Map && result['reloadToday'] == true)) {
                            _reload();
                          }
                        },
                        fat: entry.item.fat,
                        protein: entry.item.protein,
                        carbs: entry.item.carbs,
                        cells: [
                          FoodTableCell(text: entry.item.name),
                          FoodTableCell(
                            text: '${widget.metricType.formatValue(entry.value)} $metricUnit',
                          ),
                          FoodTableCell(
                            text: '${percent.toStringAsFixed(1)}%',
                            textAlign: TextAlign.end,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MetricContribution {
  const _MetricContribution({
    required this.item,
    required this.value,
  });

  final FoodItem item;
  final double value;
}
