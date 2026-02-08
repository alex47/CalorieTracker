import 'package:flutter/material.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../widgets/labeled_progress_bar.dart';
import '../main.dart';
import 'food_item_detail_screen.dart';

enum DailyMetricType { calories, fat, protein, carbs }

class DailyMetricDetailScreen extends StatefulWidget {
  const DailyMetricDetailScreen({
    super.key,
    required this.date,
    required this.metricType,
  });

  final DateTime date;
  final DailyMetricType metricType;

  @override
  State<DailyMetricDetailScreen> createState() => _DailyMetricDetailScreenState();
}

class _DailyMetricDetailScreenState extends State<DailyMetricDetailScreen> with RouteAware {
  late Future<List<FoodItem>> _itemsFuture;
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _itemsFuture = EntriesRepository.instance.fetchItemsForDate(widget.date);
  }

  void _reload() {
    setState(() {
      _itemsFuture = EntriesRepository.instance.fetchItemsForDate(widget.date);
    });
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

  String _metricLabel(AppLocalizations l10n) {
    switch (widget.metricType) {
      case DailyMetricType.calories:
        return l10n.caloriesLabel;
      case DailyMetricType.fat:
        return l10n.fatLabel;
      case DailyMetricType.protein:
        return l10n.proteinLabel;
      case DailyMetricType.carbs:
        return l10n.carbsLabel;
    }
  }

  String _metricUnit() {
    switch (widget.metricType) {
      case DailyMetricType.calories:
        return 'kcal';
      case DailyMetricType.fat:
      case DailyMetricType.protein:
      case DailyMetricType.carbs:
        return 'g';
    }
  }

  double _metricGoal() {
    final settings = SettingsService.instance.settings;
    switch (widget.metricType) {
      case DailyMetricType.calories:
        return settings.dailyGoal.toDouble();
      case DailyMetricType.fat:
        return settings.dailyFatGoal.toDouble();
      case DailyMetricType.protein:
        return settings.dailyProteinGoal.toDouble();
      case DailyMetricType.carbs:
        return settings.dailyCarbsGoal.toDouble();
    }
  }

  Color _metricColor() {
    switch (widget.metricType) {
      case DailyMetricType.calories:
        return AppColors.calories;
      case DailyMetricType.fat:
        return AppColors.fat;
      case DailyMetricType.protein:
        return AppColors.protein;
      case DailyMetricType.carbs:
        return AppColors.carbs;
    }
  }

  double _metricValue(FoodItem item) {
    switch (widget.metricType) {
      case DailyMetricType.calories:
        return item.calories.toDouble();
      case DailyMetricType.fat:
        return item.fat;
      case DailyMetricType.protein:
        return item.protein;
      case DailyMetricType.carbs:
        return item.carbs;
    }
  }

  String _formatValue(double value) {
    if (widget.metricType == DailyMetricType.calories) {
      return value.toInt().toString();
    }
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final metricLabel = _metricLabel(l10n);
    final metricUnit = _metricUnit();
    final metricColor = _metricColor();
    final metricGoal = _metricGoal();

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
          final total = items.fold<double>(0, (sum, item) => sum + _metricValue(item));

          final contributors = items
              .map((item) => _MetricContribution(item: item, value: _metricValue(item)))
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

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
                child: LabeledProgressBar(
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
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: UiConstants.tableRowHorizontalPadding,
                            vertical: UiConstants.tableRowVerticalPadding,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  l10n.foodLabel,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: metricColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  metricLabel,
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: metricColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '%',
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: metricColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ...contributors.map((entry) {
                          final percent = total > 0 ? (entry.value / total) * 100 : 0.0;
                          return InkWell(
                            onTap: () {
                              Navigator.push<dynamic>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FoodItemDetailScreen(item: entry.item, itemDate: widget.date),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: UiConstants.tableRowHorizontalPadding,
                                vertical: UiConstants.tableRowVerticalPadding,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      entry.item.name,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${_formatValue(entry.value)} $metricUnit',
                                      textAlign: TextAlign.end,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${percent.toStringAsFixed(1)}%',
                                      textAlign: TextAlign.end,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
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
