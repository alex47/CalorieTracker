import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../main.dart';
import '../models/daily_goals.dart';
import '../models/food_item.dart';
import '../models/metabolic_profile.dart';
import '../models/metric_type.dart';
import '../services/calorie_deficit_service.dart';
import '../services/entries_repository.dart';
import '../services/goal_history_service.dart';
import '../services/metabolic_profile_history_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../widgets/food_table_card.dart';
import '../widgets/labeled_group_box.dart';
import '../widgets/labeled_progress_bar.dart';
import 'about_screen.dart';
import 'add_entry_screen.dart';
import 'daily_metric_detail_screen.dart';
import 'food_item_detail_screen.dart';
import 'goals_screen.dart';
import 'metabolic_profile_screen.dart';
import 'settings_screen.dart';
import 'weekly_summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware, WidgetsBindingObserver {
  static const int _initialPage = 10000;
  static const double _progressBarHeight = UiConstants.progressBarHeight;

  late DateTime _baseDate;
  late final PageController _pageController;
  late DateTime _selectedDate;
  final Map<String, Future<List<FoodItem>>> _dayFutures = {};
  final Map<String, Future<DailyGoals>> _goalFutures = {};
  final Map<String, Future<MetabolicProfile?>> _profileFutures = {};
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _baseDate = DateTime.now();
    _pageController = PageController(initialPage: _initialPage);
    _selectedDate = _dateForPage(_initialPage);
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
    WidgetsBinding.instance.removeObserver(this);
    if (_route != null) {
      routeObserver.unsubscribe(this);
      _route = null;
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _syncToTodayIfNeeded();
    _goalFutures.clear();
    _profileFutures.clear();
    _reloadDate(_selectedDate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncToTodayIfNeeded();
    }
  }

  DateTime _dayOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    final d = _dayOnly(date);
    return '${d.year}-${d.month}-${d.day}';
  }

  DateTime _dateForPage(int page) {
    return _dayOnly(_baseDate.add(Duration(days: page - _initialPage)));
  }

  void _syncToTodayIfNeeded() {
    final today = _dayOnly(DateTime.now());
    final anchorDay = _dayOnly(_baseDate);
    if (!today.isAfter(anchorDay)) {
      return;
    }

    _dayFutures.clear();
    _goalFutures.clear();
    _profileFutures.clear();
    setState(() {
      _baseDate = today;
      _selectedDate = today;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_initialPage);
    }
  }

  Future<List<FoodItem>> _itemsForDate(DateTime date) {
    final key = _dateKey(date);
    return _dayFutures.putIfAbsent(
      key,
      () => EntriesRepository.instance.fetchItemsForDate(date),
    );
  }

  Future<DailyGoals> _goalsForDate(DateTime date, DailyGoals fallback) {
    final key = _dateKey(date);
    return _goalFutures.putIfAbsent(
      key,
      () => GoalHistoryService.instance.getEffectiveGoalsForDate(
        date: date,
        fallback: fallback,
      ),
    );
  }

  Future<MetabolicProfile?> _profileForDate(DateTime date) {
    final key = _dateKey(date);
    return _profileFutures.putIfAbsent(
      key,
      () => MetabolicProfileHistoryService.instance.getEffectiveProfileForDate(date: date),
    );
  }

  Future<void> _reloadDate(DateTime date) async {
    final day = _dayOnly(date);
    _dayFutures.remove(_dateKey(day));
    _goalFutures.remove(_dateKey(day));
    _profileFutures.remove(_dateKey(day));
    setState(() {});
    await _itemsForDate(day);
  }

  int _totalCalories(List<FoodItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.calories);
  }

  double _totalFat(List<FoodItem> items) {
    return items.fold<double>(0, (sum, item) => sum + item.fat);
  }

  double _totalProtein(List<FoodItem> items) {
    return items.fold<double>(0, (sum, item) => sum + item.protein);
  }

  double _totalCarbs(List<FoodItem> items) {
    return items.fold<double>(0, (sum, item) => sum + item.carbs);
  }

  Future<void> _navigateToAdd() async {
    await Navigator.pushNamed(
      context,
      AddEntryScreen.routeName,
      arguments: _selectedDate,
    );
    await _reloadDate(_selectedDate);
  }

  Future<void> _openMetricDetails(
    DateTime date,
    MetricType metricType,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyMetricDetailScreen(
          date: date,
          metricType: metricType,
        ),
      ),
    );
  }

  Future<void> _openWeeklySummary() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklySummaryScreen(anchorDate: _selectedDate),
      ),
    );
    await _reloadDate(_selectedDate);
  }

  bool _isTodaySelected() {
    final today = _dayOnly(DateTime.now());
    return _selectedDate == today;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = SettingsService.instance.settings;
    return PopScope(
      canPop: _isTodaySelected(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isTodaySelected()) {
          _pageController.animateToPage(
            _initialPage,
            duration: UiConstants.homePageSnapDuration,
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            PopupMenuButton<String>(
              iconSize: UiConstants.menuIconSize,
              constraints: const BoxConstraints(minWidth: UiConstants.popupMenuMinWidth),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              onSelected: (value) async {
                if (value == SettingsScreen.routeName) {
                  await Navigator.pushNamed(context, SettingsScreen.routeName);
                  if (mounted) {
                    _goalFutures.clear();
                    setState(() {});
                  }
                } else if (value == GoalsScreen.routeName) {
                  await Navigator.pushNamed(context, GoalsScreen.routeName);
                  if (mounted) {
                    _goalFutures.clear();
                    _profileFutures.clear();
                    setState(() {});
                  }
                } else if (value == MetabolicProfileScreen.routeName) {
                  await Navigator.pushNamed(context, MetabolicProfileScreen.routeName);
                  if (mounted) {
                    _profileFutures.clear();
                    setState(() {});
                  }
                } else if (value == AboutScreen.routeName) {
                  await Navigator.pushNamed(context, AboutScreen.routeName);
                  if (mounted) {
                    setState(() {});
                  }
                }
              },
              itemBuilder: (context) {
                final menuTextStyle = Theme.of(context).popupMenuTheme.textStyle;
                return [
                  PopupMenuItem(
                  value: SettingsScreen.routeName,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.settings),
                    title: Text(l10n.settingsTitle, style: menuTextStyle),
                  ),
                ),
                  PopupMenuItem(
                  value: GoalsScreen.routeName,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(l10n.goalsSectionTitle, style: menuTextStyle),
                  ),
                ),
                  PopupMenuItem(
                  value: MetabolicProfileScreen.routeName,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text(l10n.metabolicProfileTitle, style: menuTextStyle),
                  ),
                ),
                  PopupMenuItem(
                  value: AboutScreen.routeName,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: Text(l10n.aboutTitle, style: menuTextStyle),
                  ),
                ),
                ];
              },
            ),
          ],
        ),
        floatingActionButton: SizedBox(
          width: UiConstants.addButtonWidth,
          child: FilledButton.icon(
            onPressed: _navigateToAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addButton, textAlign: TextAlign.center),
          ),
        ),
        body: ScrollConfiguration(
          behavior: const _PageViewScrollBehavior(),
          child: PageView.builder(
            controller: _pageController,
            itemCount: _initialPage + 1,
            onPageChanged: (page) {
              setState(() {
                _selectedDate = _dateForPage(page);
              });
            },
            itemBuilder: (context, page) {
              final pageDate = _dateForPage(page);
              return RefreshIndicator(
                color: AppColors.text,
                onRefresh: () => _reloadDate(pageDate),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: UiConstants.largeSpacing),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                      child: Center(
                        child: InkWell(
                          onTap: _openWeeklySummary,
                          borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: UiConstants.smallSpacing,
                              vertical: UiConstants.xxSmallSpacing,
                            ),
                            child: Text(
                              formatDate(
                                pageDate,
                                languageCode: settings.languageCode,
                              ),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: UiConstants.mediumSpacing),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                      child: FutureBuilder<List<FoodItem>>(
                        future: _itemsForDate(pageDate),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: UiConstants.smallSpacing),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: UiConstants.smallSpacing),
                              child: Text(
                                l10n.failedToLoadDailyTotals,
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            );
                        }
                        final items = snapshot.data ?? const <FoodItem>[];
                        final totalCalories = _totalCalories(items);
                        final totalFat = _totalFat(items);
                        final totalProtein = _totalProtein(items);
                        final totalCarbs = _totalCarbs(items);
                        return FutureBuilder<DailyGoals>(
                          future: _goalsForDate(pageDate, DailyGoals.fromSettings(settings)),
                          builder: (context, goalSnapshot) {
                            if (goalSnapshot.connectionState == ConnectionState.waiting &&
                                !goalSnapshot.hasData) {
                              return const Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: UiConstants.smallSpacing),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final goals =
                                goalSnapshot.data ?? DailyGoals.fromSettings(settings);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTotalCard(
                                  l10n,
                                  goals.calories,
                                  totalCalories,
                                  onTap: () => _openMetricDetails(
                                    pageDate,
                                    MetricType.calories,
                                  ),
                                ),
                                const SizedBox(height: UiConstants.smallSpacing),
                                _DailyMacrosRow(
                                  l10n: l10n,
                                  fat: totalFat,
                                  fatGoal: goals.fat.toDouble(),
                                  protein: totalProtein,
                                  proteinGoal: goals.protein.toDouble(),
                                  carbs: totalCarbs,
                                  carbsGoal: goals.carbs.toDouble(),
                                  height: _progressBarHeight,
                                  onFatTap: () => _openMetricDetails(pageDate, MetricType.fat),
                                  onProteinTap: () =>
                                      _openMetricDetails(pageDate, MetricType.protein),
                                  onCarbsTap: () =>
                                      _openMetricDetails(pageDate, MetricType.carbs),
                                ),
                                const SizedBox(height: UiConstants.smallSpacing),
                                FutureBuilder<MetabolicProfile?>(
                                  future: _profileForDate(pageDate),
                                  builder: (context, profileSnapshot) {
                                    if (profileSnapshot.connectionState == ConnectionState.waiting &&
                                        !profileSnapshot.hasData) {
                                      return const Card(
                                        margin: EdgeInsets.zero,
                                        child: Padding(
                                          padding: EdgeInsets.all(UiConstants.mediumSpacing),
                                          child: Center(child: CircularProgressIndicator()),
                                        ),
                                      );
                                    }
                                    final profile = profileSnapshot.data;
                                    if (profile == null) {
                                      return Card(
                                        margin: EdgeInsets.zero,
                                        child: Padding(
                                          padding: const EdgeInsets.all(UiConstants.mediumSpacing),
                                          child: Text(l10n.setMetabolicProfileHint),
                                        ),
                                      );
                                    }
                                    final deficit = CalorieDeficitService.dailyDeficit(
                                      consumedCalories: totalCalories,
                                      profile: profile,
                                    );
                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        final singleMacroWidth =
                                            (constraints.maxWidth - (UiConstants.smallSpacing * 2)) /
                                                3;
                                        return SizedBox(
                                          width: singleMacroWidth,
                                          child: MetricGroupBox(
                                            label: l10n.dailyDeficitTitle,
                                            value: l10n.caloriesKcalValue(deficit),
                                            color: AppColors.calories,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      ),
                    ),
                    const SizedBox(height: UiConstants.largeSpacing),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                      child: Text(
                        l10n.trackedFoods,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: UiConstants.smallSpacing),
                    FutureBuilder<List<FoodItem>>(
                      future: _itemsForDate(pageDate),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: UiConstants.pagePadding,
                              vertical: UiConstants.largeSpacing,
                            ),
                            child: Text(
                              l10n.failedToLoadEntries,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          );
                        }
                        final items = snapshot.data ?? const <FoodItem>[];
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                            child: _EmptyState(l10n: l10n),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
                          child: FoodTableCard(
                            highlightRowsByDominantMacro: true,
                            columns: buildStandardFoodTableColumns(
                              firstLabel: l10n.foodLabel,
                              secondLabel: l10n.amountLabel,
                              thirdLabel: l10n.caloriesLabel,
                            ),
                            rows: items.map((item) {
                              return FoodTableRowData(
                                onTap: () async {
                                  final result = await Navigator.push<dynamic>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          FoodItemDetailScreen(item: item, itemDate: pageDate),
                                    ),
                                  );
                                  if (result == true) {
                                    await _reloadDate(pageDate);
                                    return;
                                  }
                                  if (result is Map && result['reloadToday'] == true) {
                                    await _reloadDate(DateTime.now());
                                    if (!_isTodaySelected()) {
                                      await _pageController.animateToPage(
                                        _initialPage,
                                        duration: UiConstants.homePageSnapDuration,
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                  }
                                },
                                fat: item.fat,
                                protein: item.protein,
                                carbs: item.carbs,
                                cells: [
                                  FoodTableCell(
                                    text: item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  FoodTableCell(
                                    text: item.amount,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  FoodTableCell(
                                    text: '${item.calories}',
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard(
    AppLocalizations l10n,
    int dailyGoal,
    int total,
    {
    VoidCallback? onTap,
  }
  ) {
    return LabeledProgressBar(
      label: l10n.caloriesLabel,
      value: total.toDouble(),
      goal: dailyGoal.toDouble(),
      unit: 'kcal',
      color: AppColors.calories,
      height: _progressBarHeight,
      onTap: onTap,
    );
  }
}

class _DailyMacrosRow extends StatelessWidget {
  const _DailyMacrosRow({
    required this.l10n,
    required this.fat,
    required this.fatGoal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.height,
    this.onFatTap,
    this.onProteinTap,
    this.onCarbsTap,
  });

  final AppLocalizations l10n;
  final double fat;
  final double fatGoal;
  final double protein;
  final double proteinGoal;
  final double carbs;
  final double carbsGoal;
  final double height;
  final VoidCallback? onFatTap;
  final VoidCallback? onProteinTap;
  final VoidCallback? onCarbsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LabeledProgressBar(
            label: l10n.fatLabel,
            value: fat,
            goal: fatGoal,
            color: AppColors.fat,
            height: height,
            onTap: onFatTap,
          ),
        ),
        const SizedBox(width: UiConstants.smallSpacing),
        Expanded(
          child: LabeledProgressBar(
            label: l10n.proteinLabel,
            value: protein,
            goal: proteinGoal,
            color: AppColors.protein,
            height: height,
            onTap: onProteinTap,
          ),
        ),
        const SizedBox(width: UiConstants.smallSpacing),
        Expanded(
          child: LabeledProgressBar(
            label: l10n.carbsLabel,
            value: carbs,
            goal: carbsGoal,
            color: AppColors.carbs,
            height: height,
            onTap: onCarbsTap,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UiConstants.sectionSpacing),
      child: Center(
        child: Text(l10n.emptyEntriesHint),
      ),
    );
  }
}

class _PageViewScrollBehavior extends MaterialScrollBehavior {
  const _PageViewScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
