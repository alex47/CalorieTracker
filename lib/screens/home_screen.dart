import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:calorie_tracker/l10n/app_localizations.dart';

import '../main.dart';
import '../models/daily_targets.dart';
import '../models/food_item.dart';
import '../models/metabolic_profile.dart';
import '../models/metric_type.dart';
import '../services/entries_repository.dart';
import '../services/metabolic_profile_history_service.dart';
import '../services/nutrition_target_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/ui_constants.dart';
import '../widgets/food_table_card.dart';
import '../widgets/labeled_progress_bar.dart';
import 'about_screen.dart';
import 'add_entry_screen.dart';
import 'daily_metric_detail_screen.dart';
import 'day_summary_screen.dart';
import 'food_item_detail_screen.dart';
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
  static const double _macroCounterGap = UiConstants.macroCounterGap;
  static const double _macroCounterHorizontalGap =
      _macroCounterGap + UiConstants.groupBoxHeaderTopInset;

  late DateTime _baseDate;
  late final PageController _pageController;
  late DateTime _selectedDate;
  final Map<String, Future<List<FoodItem>>> _dayFutures = {};
  final Map<String, Future<DailyTargets?>> _targetFutures = {};
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
    _targetFutures.clear();
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
    _targetFutures.clear();
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

  Future<DailyTargets?> _targetsForDate(DateTime date) {
    final key = _dateKey(date);
    return _targetFutures.putIfAbsent(
      key,
      () async {
        final profile = await _profileForDate(date);
        if (profile == null) {
          return null;
        }
        return NutritionTargetService.targetsFromProfile(profile);
      },
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
    _targetFutures.remove(_dateKey(day));
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
    final selectedDate = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklySummaryScreen(anchorDate: _selectedDate),
      ),
    );
    if (!mounted) {
      return;
    }
    if (selectedDate != null) {
      await _jumpToDate(selectedDate);
      return;
    }
    await _reloadDate(_selectedDate);
  }

  Future<void> _jumpToDate(DateTime date) async {
    final today = _dayOnly(DateTime.now());
    final target = _dayOnly(date).isAfter(today) ? today : _dayOnly(date);
    final rawPage = _initialPage + target.difference(_baseDate).inDays;
    final targetPage = rawPage.clamp(0, _initialPage).toInt();
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        targetPage,
        duration: UiConstants.homePageSnapDuration,
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedDate = _dateForPage(targetPage);
    });
    await _reloadDate(_selectedDate);
  }

  Future<void> _openDaySummaryScreen(DateTime date) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DaySummaryScreen(date: date),
      ),
    );
  }

  bool _isTodaySelected() {
    final today = _dayOnly(DateTime.now());
    return _selectedDate == today;
  }

  double _bottomActionReserveHeight(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return kMinInteractiveDimension + UiConstants.largeSpacing + safeBottom;
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
                    _targetFutures.clear();
                    setState(() {});
                  }
                } else if (value == MetabolicProfileScreen.routeName) {
                  await Navigator.pushNamed(context, MetabolicProfileScreen.routeName);
                  if (mounted) {
                    _targetFutures.clear();
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FutureBuilder<List<FoodItem>>(
                future: _itemsForDate(_selectedDate),
                builder: (context, snapshot) {
                  final hasItems = (snapshot.data ?? const <FoodItem>[]).isNotEmpty;
                  final canSummarize = snapshot.connectionState != ConnectionState.waiting && hasItems;
                  return SizedBox(
                    width: UiConstants.addButtonWidth,
                    child: FilledButton.icon(
                      onPressed: canSummarize ? () => _openDaySummaryScreen(_selectedDate) : null,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(l10n.summarizeDayButton, textAlign: TextAlign.center),
                    ),
                  );
                },
              ),
              SizedBox(
                width: UiConstants.addButtonWidth,
                child: FilledButton.icon(
                  onPressed: _navigateToAdd,
                  icon: const Icon(Icons.add_outlined),
                  label: Text(l10n.addButton, textAlign: TextAlign.center),
                ),
              ),
            ],
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: UiConstants.smallSpacing),
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
                          return FutureBuilder<DailyTargets?>(
                            future: _targetsForDate(pageDate),
                            builder: (context, targetSnapshot) {
                              if (targetSnapshot.connectionState == ConnectionState.waiting &&
                                  !targetSnapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: UiConstants.smallSpacing,
                                  ),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final targets = targetSnapshot.data;
                              if (targets == null) {
                                return Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(UiConstants.mediumSpacing),
                                    child: Text(l10n.setMetabolicProfileHint),
                                  ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTotalCard(
                                    l10n,
                                    targets.calories,
                                    totalCalories,
                                    onTap: () => _openMetricDetails(
                                      pageDate,
                                      MetricType.calories,
                                    ),
                                  ),
                                  const SizedBox(height: _macroCounterGap),
                                  _DailyMacrosRow(
                                    l10n: l10n,
                                    fat: totalFat,
                                    fatGoal: targets.fat.toDouble(),
                                    protein: totalProtein,
                                    proteinGoal: targets.protein.toDouble(),
                                    carbs: totalCarbs,
                                    carbsGoal: targets.carbs.toDouble(),
                                    height: _progressBarHeight,
                                    gap: _macroCounterHorizontalGap,
                                    onFatTap: () => _openMetricDetails(pageDate, MetricType.fat),
                                    onProteinTap: () =>
                                        _openMetricDetails(pageDate, MetricType.protein),
                                    onCarbsTap: () =>
                                        _openMetricDetails(pageDate, MetricType.carbs),
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
                        final content = items.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: UiConstants.pagePadding,
                                ),
                                child: _EmptyState(l10n: l10n),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: UiConstants.pagePadding,
                                ),
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
                        return content;
                      },
                    ),
                    SizedBox(height: _bottomActionReserveHeight(context)),
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
    int total, {
    VoidCallback? onTap,
  }) {
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
    required this.gap,
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
  final double gap;
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
        SizedBox(width: gap),
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
        SizedBox(width: gap),
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
