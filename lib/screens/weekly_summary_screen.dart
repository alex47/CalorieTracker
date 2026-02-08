import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_goals.dart';
import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/goal_history_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';

enum WeeklyMetricType { calories, fat, protein, carbs }

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
    final fallbackGoals = DailyGoals.fromSettings(SettingsService.instance.settings);
    final goalsByDate = await GoalHistoryService.instance.getEffectiveGoalsForDateRange(
      startDate: weekStart,
      endDate: weekEnd,
      fallback: fallbackGoals,
    );
    return List<_DayMetricTotals>.generate(
      7,
      (index) {
        final date = weekStart.add(Duration(days: index));
        final dateKey = _weekKey(date);
        return _DayMetricTotals.fromItems(
          date: date,
          goals: goalsByDate[dateKey] ?? fallbackGoals,
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

  double _metricValue(WeeklyMetricType metric, _DayMetricTotals totals) {
    switch (metric) {
      case WeeklyMetricType.calories:
        return totals.calories.toDouble();
      case WeeklyMetricType.fat:
        return totals.fat;
      case WeeklyMetricType.protein:
        return totals.protein;
      case WeeklyMetricType.carbs:
        return totals.carbs;
    }
  }

  Color _metricColor(WeeklyMetricType metric) {
    switch (metric) {
      case WeeklyMetricType.calories:
        return AppColors.calories;
      case WeeklyMetricType.fat:
        return AppColors.fat;
      case WeeklyMetricType.protein:
        return AppColors.protein;
      case WeeklyMetricType.carbs:
        return AppColors.carbs;
    }
  }

  bool _isCurrentWeekSelected() => _selectedPage == _maxPage;

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
              _selectedPage = page;
            },
            itemBuilder: (context, page) {
            final weekStart = _weekStartForPage(page);
            final weekEnd = weekStart.add(const Duration(days: 6));

            return RefreshIndicator(
              color: Colors.white,
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

                  final specs = <_WeeklyMetricSpec>[
                    _WeeklyMetricSpec(
                      color: _metricColor(WeeklyMetricType.calories),
                      goalForDay: (day) => day.goals.calories.toDouble(),
                      valueForDay: (day) => _metricValue(WeeklyMetricType.calories, day),
                    ),
                    _WeeklyMetricSpec(
                      color: _metricColor(WeeklyMetricType.fat),
                      goalForDay: (day) => day.goals.fat.toDouble(),
                      valueForDay: (day) => _metricValue(WeeklyMetricType.fat, day),
                    ),
                    _WeeklyMetricSpec(
                      color: _metricColor(WeeklyMetricType.protein),
                      goalForDay: (day) => day.goals.protein.toDouble(),
                      valueForDay: (day) => _metricValue(WeeklyMetricType.protein, day),
                    ),
                    _WeeklyMetricSpec(
                      color: _metricColor(WeeklyMetricType.carbs),
                      goalForDay: (day) => day.goals.carbs.toDouble(),
                      valueForDay: (day) => _metricValue(WeeklyMetricType.carbs, day),
                    ),
                  ];

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      const headerHeightEstimate = 90.0;
                      final chartHeight = (constraints.maxHeight - headerHeightEstimate)
                          .clamp(220.0, 10000.0)
                          .toDouble();

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: UiConstants.largeSpacing),
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: UiConstants.smallSpacing,
                                  vertical: UiConstants.xxSmallSpacing,
                                ),
                                child: Text(
                                  _formatWeekRange(languageCode, weekStart, weekEnd),
                                  style: Theme.of(context).textTheme.headlineSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: UiConstants.mediumSpacing),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                            child: SizedBox(
                              height: chartHeight,
                              child: _CombinedMetricWeekChart(
                                specs: specs,
                                days: dailyTotals,
                                languageCode: languageCode,
                              ),
                            ),
                          ),
                          if (dailyTotals.every((day) => day.itemCount == 0))
                            Padding(
                              padding: const EdgeInsets.only(
                                top: UiConstants.largeSpacing,
                                left: UiConstants.pagePadding,
                                right: UiConstants.pagePadding,
                              ),
                              child: Text(l10n.noEntriesForWeek),
                            ),
                        ],
                      );
                    },
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
  });

  final List<_WeeklyMetricSpec> specs;
  final List<_DayMetricTotals> days;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(UiConstants.mediumSpacing),
        child: Column(
          children: [
            for (int i = 0; i < days.length; i++) ...[
              Expanded(
                flex: specs.length,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        DateFormat.E(languageCode).format(days[i].date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: specs.map((spec) {
                          final value = spec.valueForDay(days[i]);
                          final goal = spec.goalForDay(days[i]);
                          final isOverGoal = goal > 0 && value > goal;
                          final stripedFillColor = spec.color.withValues(alpha: 0.42);
                          final fillColor = isOverGoal ? Colors.transparent : stripedFillColor;
                          final max = goal > 0 ? goal : 1.0;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: (value / max).clamp(0.0, 1.0),
                                  heightFactor: 1.0,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: fillColor,
                                            border: Border.all(color: spec.color),
                                            borderRadius: BorderRadius.circular(3),
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
              if (i < days.length - 1) const Spacer(flex: 1),
            ],
          ],
        ),
      ),
    );
  }
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
    required this.goals,
    required this.itemCount,
    required this.calories,
    required this.fat,
    required this.protein,
    required this.carbs,
  });

  final DateTime date;
  final DailyGoals goals;
  final int itemCount;
  final int calories;
  final double fat;
  final double protein;
  final double carbs;

  factory _DayMetricTotals.fromItems({
    required DateTime date,
    required DailyGoals goals,
    required List<FoodItem> items,
  }) {
    return _DayMetricTotals(
      date: date,
      goals: goals,
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
    const double spacing = 6;
    const double strokeWidth = 1.2;
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
