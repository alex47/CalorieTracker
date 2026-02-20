import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_targets.dart';
import '../models/food_item.dart';
import '../models/metric_type.dart';
import '../services/entries_repository.dart';
import '../services/metabolic_profile_history_service.dart';
import '../services/nutrition_target_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../widgets/labeled_group_box.dart';

class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({
    super.key,
    required this.anchorDate,
  });

  static const routeName = '/weekly-summary';

  final DateTime anchorDate;

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  static const int _initialPage = 10000;

  late final DateTime _baseWeekStart;
  late final PageController _pageController;
  late int _selectedPage;
  late final int _maxPage;
  final Map<String, Future<List<_DayMetricTotals>>> _weekFutures = {};

  @override
  void initState() {
    super.initState();
    _baseWeekStart = _startOfWeek(widget.anchorDate);
    final currentWeekStart = _startOfWeek(DateTime.now());
    final weeksUntilCurrent =
        currentWeekStart.difference(_baseWeekStart).inDays ~/ 7;
    _maxPage = _initialPage + (weeksUntilCurrent < 0 ? 0 : weeksUntilCurrent);
    _pageController = PageController(initialPage: _initialPage);
    _selectedPage = _initialPage;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    return dayOnly.subtract(Duration(days: dayOnly.weekday - DateTime.monday));
  }

  Future<List<_DayMetricTotals>> _loadWeekTotals(DateTime weekStart) async {
    final futures = List<Future<List<FoodItem>>>.generate(
      7,
      (index) => EntriesRepository.instance.fetchItemsForDate(
        weekStart.add(Duration(days: index)),
      ),
    );
    final dailyItems = await Future.wait(futures);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final profilesByDate = await MetabolicProfileHistoryService.instance.getEffectiveProfileForDateRange(
      startDate: weekStart,
      endDate: weekEnd,
    );
    return List<_DayMetricTotals>.generate(
      7,
      (index) {
        final date = weekStart.add(Duration(days: index));
        final dateKey = _weekKey(date);
        final profile = profilesByDate[dateKey];
        final targets = profile == null ? null : NutritionTargetService.targetsFromProfile(profile);
        return _DayMetricTotals.fromItems(
          date: date,
          targets: targets,
          items: dailyItems[index],
        );
      },
    );
  }

  String _weekKey(DateTime weekStart) {
    final month = weekStart.month.toString().padLeft(2, '0');
    final day = weekStart.day.toString().padLeft(2, '0');
    return '${weekStart.year}-$month-$day';
  }

  DateTime _weekStartForPage(int page) {
    return _baseWeekStart.add(Duration(days: (page - _initialPage) * 7));
  }

  Future<List<_DayMetricTotals>> _totalsForWeek(DateTime weekStart) {
    final key = _weekKey(weekStart);
    return _weekFutures.putIfAbsent(key, () => _loadWeekTotals(weekStart));
  }

  Future<void> _reloadWeek(DateTime weekStart) async {
    setState(() {
      _weekFutures.remove(_weekKey(weekStart));
    });
    await _totalsForWeek(weekStart);
  }

  bool _isCurrentWeekSelected() => _selectedPage == _maxPage;

  DateTime _todayDayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isFutureDay(DateTime day) => day.isAfter(_todayDayOnly());
  bool _isToday(DateTime day) => day.isAtSameMomentAs(_todayDayOnly());

  void _openDay(DateTime date) {
    if (_isFutureDay(date)) {
      return;
    }
    Navigator.of(context).pop(DateTime(date.year, date.month, date.day));
  }

  List<int?>? _resolvedDailyDeficits(List<_DayMetricTotals> dailyTotals) {
    final deficitValues = dailyTotals
        .where((day) {
          if (_isFutureDay(day.date) || _isToday(day.date)) {
            return false;
          }
          return day.itemCount > 0 && day.targets != null;
        })
        .map((day) => day.targets!.calories - day.calories)
        .toList(growable: false);
    if (deficitValues.isEmpty) {
      return null;
    }

    final average = deficitValues.reduce((a, b) => a + b) / deficitValues.length;
    return dailyTotals.map((day) {
      if (_isFutureDay(day.date)) {
        return null;
      }
      if (_isToday(day.date)) {
        if (day.itemCount > 0 && day.targets != null) {
          return day.targets!.calories - day.calories;
        }
        return null;
      }
      if (day.itemCount > 0 && day.targets != null) {
        return day.targets!.calories - day.calories;
      }
      return average.round();
    }).toList(growable: false);
  }

  String _weeklyDeficitDisplay(
    List<_DayMetricTotals> dailyTotals,
    AppLocalizations l10n,
  ) {
    if (dailyTotals.any((day) => _isFutureDay(day.date))) {
      return '-';
    }
    final resolvedDeficits = _resolvedDailyDeficits(dailyTotals);
    if (resolvedDeficits == null) {
      return '-';
    }
    final nonNull = resolvedDeficits.whereType<int>().toList(growable: false);
    if (nonNull.isEmpty) {
      return '-';
    }
    final weeklyDeficit = nonNull.fold<int>(0, (sum, value) => sum + value);
    return l10n.caloriesKcalValue(weeklyDeficit);
  }

  List<_DisplayedDailyDeficit?>? _dailyDeficitDisplayValues(List<_DayMetricTotals> dailyTotals) {
    final resolvedDeficits = _resolvedDailyDeficits(dailyTotals);
    if (resolvedDeficits == null) {
      return null;
    }
    final result = <_DisplayedDailyDeficit?>[];
    for (var i = 0; i < dailyTotals.length; i++) {
      final day = dailyTotals[i];
      if (_isFutureDay(day.date)) {
        result.add(null);
        continue;
      }
      if (_isToday(day.date)) {
        if (day.itemCount > 0 && day.targets != null) {
          result.add(
            _DisplayedDailyDeficit(
              value: day.targets!.calories - day.calories,
              estimated: false,
            ),
          );
        } else {
          result.add(null);
        }
        continue;
      }
      if (day.itemCount > 0 && day.targets != null) {
        result.add(
          _DisplayedDailyDeficit(
            value: day.targets!.calories - day.calories,
            estimated: false,
          ),
        );
      } else {
        result.add(
          _DisplayedDailyDeficit(
            value: resolvedDeficits[i]!,
            estimated: true,
          ),
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = SettingsService.instance.settings.languageCode;

    return PopScope(
      canPop: _isCurrentWeekSelected(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isCurrentWeekSelected()) {
          _pageController.animateToPage(
            _maxPage,
            duration: UiConstants.homePageSnapDuration,
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_view_week_outlined),
              const SizedBox(width: UiConstants.appBarIconTextSpacing),
              Text(l10n.weeklySummaryTitle),
            ],
          ),
        ),
        body: ScrollConfiguration(
          behavior: const _PageViewScrollBehavior(),
          child: PageView.builder(
            controller: _pageController,
            itemCount: _maxPage + 1,
            onPageChanged: (page) {
              setState(() {
                _selectedPage = page;
              });
            },
            itemBuilder: (context, page) {
            final weekStart = _weekStartForPage(page);
            final weekEnd = weekStart.add(const Duration(days: 6));

            return RefreshIndicator(
              color: AppColors.text,
              onRefresh: () => _reloadWeek(weekStart),
              child: FutureBuilder<List<_DayMetricTotals>>(
                future: _totalsForWeek(weekStart),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(UiConstants.pagePadding),
                      children: [
                        Text(
                          l10n.failedToLoadEntries,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    );
                  }

                  final dailyTotals = snapshot.data ?? const <_DayMetricTotals>[];
                  final hasAnyTargets = dailyTotals.any((day) => day.targets != null);
                  final displayDailyDeficits = _dailyDeficitDisplayValues(dailyTotals);

                  final specs = <_WeeklyMetricSpec>[
                    _WeeklyMetricSpec(
                      color: MetricType.calories.color,
                      goalForDay: (day) => day.targets?.calories.toDouble() ?? 0,
                      valueForDay: (day) => MetricType.calories.valueFromTotals(
                        calories: day.calories,
                        fat: day.fat,
                        protein: day.protein,
                        carbs: day.carbs,
                      ),
                    ),
                    _WeeklyMetricSpec(
                      color: MetricType.fat.color,
                      goalForDay: (day) => day.targets?.fat.toDouble() ?? 0,
                      valueForDay: (day) => MetricType.fat.valueFromTotals(
                        calories: day.calories,
                        fat: day.fat,
                        protein: day.protein,
                        carbs: day.carbs,
                      ),
                    ),
                    _WeeklyMetricSpec(
                      color: MetricType.protein.color,
                      goalForDay: (day) => day.targets?.protein.toDouble() ?? 0,
                      valueForDay: (day) => MetricType.protein.valueFromTotals(
                        calories: day.calories,
                        fat: day.fat,
                        protein: day.protein,
                        carbs: day.carbs,
                      ),
                    ),
                    _WeeklyMetricSpec(
                      color: MetricType.carbs.color,
                      goalForDay: (day) => day.targets?.carbs.toDouble() ?? 0,
                      valueForDay: (day) => MetricType.carbs.valueFromTotals(
                        calories: day.calories,
                        fat: day.fat,
                        protein: day.protein,
                        carbs: day.carbs,
                      ),
                    ),
                  ];

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(
                        child: SizedBox(height: UiConstants.mediumSpacing),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: UiConstants.pagePadding,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: UiConstants.smallSpacing,
                                vertical: UiConstants.xxSmallSpacing,
                              ),
                              child: Text(
                                _formatWeekRange(languageCode, weekStart, weekEnd),
                                style: Theme.of(context).textTheme.headlineSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: UiConstants.largeSpacing),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                          child: LabeledGroupBox(
                            label: l10n.weeklyDeficitTitle,
                            value: '',
                            borderColor: AppColors.deficit,
                            textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.deficit,
                                ),
                            contentHeight: UiConstants.progressBarHeight,
                            contentPadding: EdgeInsets.zero,
                            backgroundColor: Colors.transparent,
                            child: Center(
                              child: Text(
                                _weeklyDeficitDisplay(dailyTotals, l10n),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.deficit,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: UiConstants.largeSpacing),
                      ),
                      if (!hasAnyTargets)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: UiConstants.pagePadding,
                            ),
                            child: Text(l10n.setMetabolicProfileHint),
                          ),
                        ),
                      if (dailyTotals.every((day) => day.itemCount == 0))
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: UiConstants.largeSpacing,
                              left: UiConstants.pagePadding,
                              right: UiConstants.pagePadding,
                            ),
                            child: Text(l10n.noEntriesForWeek),
                          ),
                        ),
                      if (hasAnyTargets)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: UiConstants.pagePadding,
                              right: UiConstants.pagePadding,
                              bottom: UiConstants.pagePadding,
                            ),
                            child: _CombinedMetricWeekChart(
                              specs: specs,
                              days: dailyTotals,
                              languageCode: languageCode,
                              dailyDeficits: displayDailyDeficits,
                              onDayTap: _openDay,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
            },
          ),
        ),
      ),
    );
  }

  String _formatWeekRange(String languageCode, DateTime weekStart, DateTime weekEnd) {
    final formatter = DateFormat.MMMMd(languageCode);
    return '${formatter.format(weekStart)} - ${formatter.format(weekEnd)}';
  }
}

class _PageViewScrollBehavior extends MaterialScrollBehavior {
  const _PageViewScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class _CombinedMetricWeekChart extends StatelessWidget {
  const _CombinedMetricWeekChart({
    required this.specs,
    required this.days,
    required this.languageCode,
    required this.dailyDeficits,
    required this.onDayTap,
  });

  final List<_WeeklyMetricSpec> specs;
  final List<_DayMetricTotals> days;
  final String languageCode;
  final List<_DisplayedDailyDeficit?>? dailyDeficits;
  final ValueChanged<DateTime> onDayTap;

  String _formatDailyDeficit(int dayIndex) {
    if (dailyDeficits == null || dayIndex < 0 || dayIndex >= dailyDeficits!.length) {
      return '-';
    }
    final deficit = dailyDeficits![dayIndex];
    if (deficit == null) {
      return '-';
    }
    return '${deficit.value} kcal';
  }

  bool _isEstimatedDailyDeficit(int dayIndex) {
    if (dailyDeficits == null || dayIndex < 0 || dayIndex >= dailyDeficits!.length) {
      return false;
    }
    final deficit = dailyDeficits![dayIndex];
    if (deficit == null) {
      return false;
    }
    return deficit.estimated;
  }

  String _formatDayName(DateTime date) {
    final value = DateFormat.EEEE(languageCode).format(date);
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return LabeledGroupBox(
      label: '',
      value: '',
      borderColor: AppColors.subtleBorder,
      textStyle: Theme.of(context).textTheme.bodyMedium,
      backgroundColor: Colors.transparent,
      contentPadding: const EdgeInsets.all(UiConstants.mediumSpacing),
      child: Column(
        children: [
          for (int i = 0; i < days.length; i++) ...[
            Expanded(
              flex: specs.length,
              child: InkWell(
                onTap: () => onDayTap(days[i].date),
                borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 116,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDayName(days[i].date),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: UiConstants.xxSmallSpacing),
                          Text(
                            _formatDailyDeficit(i),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.deficit,
                                  fontStyle: _isEstimatedDailyDeficit(i)
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: specs.map((spec) {
                          final value = spec.valueForDay(days[i]);
                          final goal = spec.goalForDay(days[i]);
                          final isOverGoal = goal > 0 && value > goal;
                          final stripedFillColor =
                              spec.color.withValues(alpha: AppColors.weeklyChartStripeAlpha);
                          final fillColor = isOverGoal ? Colors.transparent : stripedFillColor;
                          final max = goal > 0 ? goal : 1.0;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: UiConstants.weeklyChartBarVerticalPadding,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: (value / max).clamp(0.0, 1.0),
                                  heightFactor: 1.0,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      UiConstants.weeklyChartBarCornerRadius,
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: fillColor,
                                            border: Border.all(color: spec.color),
                                            borderRadius: BorderRadius.circular(
                                              UiConstants.weeklyChartBarCornerRadius,
                                            ),
                                          ),
                                        ),
                                        if (isOverGoal)
                                          CustomPaint(
                                            painter: _DiagonalStripePainter(
                                              stripeColor: stripedFillColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < days.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: UiConstants.smallSpacing),
                child: Divider(
                  color: AppColors.subtleBorder,
                  thickness: UiConstants.borderWidth,
                  height: UiConstants.borderWidth,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DisplayedDailyDeficit {
  const _DisplayedDailyDeficit({
    required this.value,
    required this.estimated,
  });

  final int value;
  final bool estimated;
}

class _WeeklyMetricSpec {
  const _WeeklyMetricSpec({
    required this.color,
    required this.goalForDay,
    required this.valueForDay,
  });

  final Color color;
  final double Function(_DayMetricTotals day) goalForDay;
  final double Function(_DayMetricTotals day) valueForDay;
}

class _DayMetricTotals {
  const _DayMetricTotals({
    required this.date,
    required this.targets,
    required this.itemCount,
    required this.calories,
    required this.fat,
    required this.protein,
    required this.carbs,
  });

  final DateTime date;
  final DailyTargets? targets;
  final int itemCount;
  final int calories;
  final double fat;
  final double protein;
  final double carbs;

  factory _DayMetricTotals.fromItems({
    required DateTime date,
    required DailyTargets? targets,
    required List<FoodItem> items,
  }) {
    return _DayMetricTotals(
      date: date,
      targets: targets,
      itemCount: items.length,
      calories: items.fold<int>(0, (sum, item) => sum + item.calories),
      fat: items.fold<double>(0, (sum, item) => sum + item.fat),
      protein: items.fold<double>(0, (sum, item) => sum + item.protein),
      carbs: items.fold<double>(0, (sum, item) => sum + item.carbs),
    );
  }
}

class _DiagonalStripePainter extends CustomPainter {
  const _DiagonalStripePainter({
    required this.stripeColor,
  });

  final Color stripeColor;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = UiConstants.weeklyChartStripeSpacing;
    const strokeWidth = UiConstants.weeklyChartStripeStrokeWidth;
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    for (double x = -size.height; x < size.width; x += spacing) {
      final start = Offset(x, size.height);
      final end = Offset(x + size.height, 0);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalStripePainter oldDelegate) {
    return oldDelegate.stripeColor != stripeColor;
  }
}
