import 'package:calorie_tracker/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_targets.dart';
import '../models/food_item.dart';
import '../models/metabolic_profile.dart';
import '../models/metric_type.dart';
import '../services/entries_repository.dart';
import '../services/metabolic_profile_history_service.dart';
import '../services/nutrition_target_service.dart';
import '../services/settings_service.dart';
import '../services/weekly_deficit_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../utils/app_date_utils.dart';
import '../widgets/labeled_group_box.dart';

typedef WeeklyItemsLoadOperation = Future<List<FoodItem>> Function(
  DateTime date,
);
typedef WeeklyProfilesLoadOperation = Future<Map<String, MetabolicProfile?>>
    Function({
  required DateTime startDate,
  required DateTime endDate,
});

class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({
    super.key,
    required this.anchorDate,
    this.now,
    this.languageCode,
    this.loadItems,
    this.loadProfiles,
    this.onDaySelected,
  });

  static const routeName = '/weekly-summary';

  final DateTime anchorDate;
  final DateTime Function()? now;
  final String? languageCode;
  final WeeklyItemsLoadOperation? loadItems;
  final WeeklyProfilesLoadOperation? loadProfiles;
  final ValueChanged<DateTime>? onDaySelected;

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
  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _baseWeekStart = _startOfWeek(widget.anchorDate);
    final currentWeekStart = _startOfWeek(_now());
    final weeksUntilCurrent = AppDateUtils.calendarWeeksBetween(
      _baseWeekStart,
      currentWeekStart,
    );
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
    return AppDateUtils.startOfWeekMonday(date);
  }

  Future<List<_DayMetricTotals>> _loadWeekTotals(DateTime weekStart) async {
    final futures = List<Future<List<FoodItem>>>.generate(
      7,
      (index) {
        final date = AppDateUtils.addCalendarDays(weekStart, index);
        return widget.loadItems?.call(date) ??
            EntriesRepository.instance.fetchItemsForDate(date);
      },
    );
    final dailyItems = await Future.wait(futures);
    final weekEnd = AppDateUtils.addCalendarDays(weekStart, 6);
    final profilesByDate = await (widget.loadProfiles?.call(
          startDate: weekStart,
          endDate: weekEnd,
        ) ??
        MetabolicProfileHistoryService.instance.getEffectiveProfileForDateRange(
          startDate: weekStart,
          endDate: weekEnd,
        ));
    return List<_DayMetricTotals>.generate(
      7,
      (index) {
        final date = AppDateUtils.addCalendarDays(weekStart, index);
        final dateKey = _weekKey(date);
        final profile = profilesByDate[dateKey];
        final targets = profile == null
            ? null
            : NutritionTargetService.targetsFromProfile(profile);
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
    return AppDateUtils.addCalendarDays(
      _baseWeekStart,
      (page - _initialPage) * 7,
    );
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
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isFutureDay(DateTime day) => day.isAfter(_todayDayOnly());
  bool _isCompletedWeek(List<_DayMetricTotals> dailyTotals) {
    if (dailyTotals.isEmpty) {
      return false;
    }
    return dailyTotals.last.date.isBefore(_todayDayOnly());
  }

  void _openDay(DateTime date) {
    if (_isFutureDay(date)) {
      return;
    }
    if (widget.onDaySelected != null) {
      widget.onDaySelected!(DateTime(date.year, date.month, date.day));
      return;
    }
    Navigator.of(context).pop(DateTime(date.year, date.month, date.day));
  }

  List<ResolvedDailyDeficit?>? _resolvedDailyDeficits(
    List<_DayMetricTotals> dailyTotals,
  ) {
    return WeeklyDeficitCalculator.resolveDailyDeficits(
      days: dailyTotals
          .map(
            (day) => WeeklyDeficitDay(
              date: day.date,
              calorieTarget: day.targets?.calories,
              itemCount: day.itemCount,
              calories: day.calories,
            ),
          )
          .toList(growable: false),
      today: _todayDayOnly(),
    );
  }

  String _weeklyDeficitDisplay(
    List<_DayMetricTotals> dailyTotals,
    List<ResolvedDailyDeficit?>? resolvedDeficits,
    AppLocalizations l10n,
  ) {
    if (!_isCompletedWeek(dailyTotals)) {
      return '-';
    }
    if (resolvedDeficits == null) {
      return '-';
    }
    final nonNull = resolvedDeficits
        .whereType<ResolvedDailyDeficit>()
        .toList(growable: false);
    if (nonNull.isEmpty) {
      return '-';
    }
    final weeklyDeficit =
        nonNull.fold<int>(0, (sum, deficit) => sum + deficit.value);
    final display = l10n.caloriesKcalValue(weeklyDeficit);
    return nonNull.any((deficit) => deficit.estimated) ? '$display*' : display;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode =
        widget.languageCode ?? SettingsService.instance.settings.languageCode;

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
              final weekEnd = AppDateUtils.addCalendarDays(weekStart, 6);

              return RefreshIndicator(
                color: AppColors.text,
                onRefresh: () => _reloadWeek(weekStart),
                child: FutureBuilder<List<_DayMetricTotals>>(
                  future: _totalsForWeek(weekStart),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(UiConstants.pagePadding),
                        children: [
                          Text(
                            l10n.failedToLoadEntries,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                      );
                    }

                    final dailyTotals =
                        snapshot.data ?? const <_DayMetricTotals>[];
                    final hasAnyTargets =
                        dailyTotals.any((day) => day.targets != null);
                    final displayDailyDeficits =
                        _resolvedDailyDeficits(dailyTotals);
                    final hasEstimatedDeficits = displayDailyDeficits?.any(
                          (deficit) => deficit?.estimated ?? false,
                        ) ??
                        false;

                    final specs = <_WeeklyMetricSpec>[
                      _WeeklyMetricSpec(
                        color: MetricType.calories.color,
                        goalForDay: (day) =>
                            day.targets?.calories.toDouble() ?? 0,
                        valueForDay: (day) =>
                            MetricType.calories.valueFromTotals(
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
                        goalForDay: (day) =>
                            day.targets?.protein.toDouble() ?? 0,
                        valueForDay: (day) =>
                            MetricType.protein.valueFromTotals(
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
                                  _formatWeekRange(
                                      languageCode, weekStart, weekEnd),
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: UiConstants.pagePadding),
                            child: LabeledGroupBox(
                              label: l10n.weeklyDeficitTitle,
                              value: '',
                              borderColor: AppColors.deficit,
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.deficit,
                                  ),
                              contentHeight: UiConstants.progressBarHeight,
                              contentPadding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              child: Center(
                                child: Text(
                                  _weeklyDeficitDisplay(
                                    dailyTotals,
                                    displayDailyDeficits,
                                    l10n,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.deficit,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (hasEstimatedDeficits)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: UiConstants.smallSpacing,
                                left: UiConstants.pagePadding,
                                right: UiConstants.pagePadding,
                              ),
                              child: Text(
                                l10n.weeklyDeficitEstimateHint,
                                style: Theme.of(context).textTheme.bodySmall,
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

  String _formatWeekRange(
      String languageCode, DateTime weekStart, DateTime weekEnd) {
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
  final List<ResolvedDailyDeficit?>? dailyDeficits;
  final ValueChanged<DateTime> onDayTap;

  String _formatDailyDeficit(int dayIndex) {
    if (dailyDeficits == null ||
        dayIndex < 0 ||
        dayIndex >= dailyDeficits!.length) {
      return '-';
    }
    final deficit = dailyDeficits![dayIndex];
    if (deficit == null) {
      return '-';
    }
    return '${deficit.value} kcal${deficit.estimated ? '*' : ''}';
  }

  bool _isEstimatedDailyDeficit(int dayIndex) {
    if (dailyDeficits == null ||
        dayIndex < 0 ||
        dayIndex >= dailyDeficits!.length) {
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
                          final stripedFillColor = spec.color.withValues(
                              alpha: AppColors.weeklyChartStripeAlpha);
                          final fillColor = isOverGoal
                              ? Colors.transparent
                              : stripedFillColor;
                          final max = goal > 0 ? goal : 1.0;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical:
                                    UiConstants.weeklyChartBarVerticalPadding,
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
                                            border:
                                                Border.all(color: spec.color),
                                            borderRadius: BorderRadius.circular(
                                              UiConstants
                                                  .weeklyChartBarCornerRadius,
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
                padding:
                    EdgeInsets.symmetric(vertical: UiConstants.smallSpacing),
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
