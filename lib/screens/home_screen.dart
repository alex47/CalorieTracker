import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../main.dart';
import '../models/daily_goals.dart';
import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/goal_history_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../widgets/labeled_progress_bar.dart';
import 'about_screen.dart';
import 'add_entry_screen.dart';
import 'daily_metric_detail_screen.dart';
import 'food_item_detail_screen.dart';
import 'settings_screen.dart';
import 'weekly_summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  static const int _initialPage = 10000;
  static const double _progressBarHeight = UiConstants.progressBarHeight;

  late final DateTime _baseDate;
  late final PageController _pageController;
  late DateTime _selectedDate;
  final Map<String, Future<List<FoodItem>>> _dayFutures = {};
  final Map<String, Future<DailyGoals>> _goalFutures = {};
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
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
    if (_route != null) {
      routeObserver.unsubscribe(this);
      _route = null;
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _goalFutures.clear();
    _reloadDate(_selectedDate);
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

  Future<void> _reloadDate(DateTime date) async {
    final day = _dayOnly(date);
    _dayFutures.remove(_dateKey(day));
    _goalFutures.remove(_dateKey(day));
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
    DailyMetricType metricType,
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

  Future<bool> _onWillPop() async {
    if (!_isTodaySelected()) {
      await _pageController.animateToPage(
        _initialPage,
        duration: UiConstants.homePageSnapDuration,
        curve: Curves.easeOutCubic,
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = SettingsService.instance.settings;
    return WillPopScope(
      onWillPop: _onWillPop,
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
            label: Text(l10n.addButton),
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
                color: Colors.white,
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
                                    DailyMetricType.calories,
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
                                  onFatTap: () => _openMetricDetails(pageDate, DailyMetricType.fat),
                                  onProteinTap: () =>
                                      _openMetricDetails(pageDate, DailyMetricType.protein),
                                  onCarbsTap: () =>
                                      _openMetricDetails(pageDate, DailyMetricType.carbs),
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
                          child: _ItemsTable(
                            l10n: l10n,
                            items: items,
                            onItemTap: (item) async {
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

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({
    required this.l10n,
    required this.items,
    required this.onItemTap,
  });

  final AppLocalizations l10n;
  final List<FoodItem> items;
  final Future<void> Function(FoodItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _ItemsHeaderRow(
            l10n: l10n,
            textTheme: Theme.of(context).textTheme,
          ),
          const Divider(height: 1),
          ...items.map(
            (item) => InkWell(
              onTap: () async => onItemTap(item),
              child: _ItemsDataRow(item: item),
            ),
          ),
        ],
      ),
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

class _ItemsHeaderRow extends StatelessWidget {
  const _ItemsHeaderRow({
    required this.l10n,
    required this.textTheme,
  });

  final AppLocalizations l10n;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UiConstants.tableRowHorizontalPadding,
        vertical: UiConstants.tableRowVerticalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(l10n.foodLabel, style: textTheme.labelLarge),
          ),
          Expanded(
            flex: 3,
            child: Text(l10n.amountLabel, style: textTheme.labelLarge),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n.caloriesLabel,
              style: textTheme.labelLarge,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsDataRow extends StatelessWidget {
  const _ItemsDataRow({required this.item});

  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UiConstants.tableRowHorizontalPadding,
        vertical: UiConstants.tableRowVerticalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              item.amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.calories}',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
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
