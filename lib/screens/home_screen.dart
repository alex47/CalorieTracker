import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../main.dart';
import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/labeled_progress_bar.dart';
import 'about_screen.dart';
import 'add_entry_screen.dart';
import 'food_item_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _initialPage = 10000;
  static const double _progressBarHeight = 36;

  late final DateTime _baseDate;
  late final PageController _pageController;
  late DateTime _selectedDate;
  final Map<String, Future<List<FoodItem>>> _dayFutures = {};

  @override
  void initState() {
    super.initState();
    _baseDate = DateTime.now();
    _pageController = PageController(initialPage: _initialPage);
    _selectedDate = _dateForPage(_initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  Future<void> _reloadDate(DateTime date) async {
    final day = _dayOnly(date);
    _dayFutures.remove(_dateKey(day));
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

  bool _isTodaySelected() {
    final today = _dayOnly(DateTime.now());
    return _selectedDate == today;
  }

  Future<bool> _onWillPop() async {
    if (!_isTodaySelected()) {
      await _pageController.animateToPage(
        _initialPage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.settings;
    final dailyGoal = settings.dailyGoal;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Calorie Tracker'),
          actions: [
            PopupMenuButton<String>(
              iconSize: 30,
              constraints: const BoxConstraints(minWidth: 220),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              onSelected: (value) {
                if (value == SettingsScreen.routeName) {
                  Navigator.pushNamed(context, SettingsScreen.routeName);
                } else if (value == AboutScreen.routeName) {
                  Navigator.pushNamed(context, AboutScreen.routeName);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: SettingsScreen.routeName,
                  child: Text('Settings'),
                ),
                const PopupMenuItem(
                  value: AboutScreen.routeName,
                  child: Text('About'),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _navigateToAdd,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 36),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
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
                onRefresh: () => _reloadDate(pageDate),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: Text(
                          formatDate(pageDate),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FutureBuilder<List<FoodItem>>(
                        future: _itemsForDate(pageDate),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Failed to load daily totals.',
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            );
                          }
                          final items = snapshot.data ?? const <FoodItem>[];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTotalCard(
                                dailyGoal,
                                _totalCalories(items),
                              ),
                              const SizedBox(height: 8),
                              _DailyMacrosRow(
                                fat: _totalFat(items),
                                fatGoal: settings.dailyFatGoal.toDouble(),
                                protein: _totalProtein(items),
                                proteinGoal: settings.dailyProteinGoal.toDouble(),
                                carbs: _totalCarbs(items),
                                carbsGoal: settings.dailyCarbsGoal.toDouble(),
                                height: _progressBarHeight,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Tracked foods',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<FoodItem>>(
                      future: _itemsForDate(pageDate),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Text(
                              'Failed to load entries.',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          );
                        }
                        final items = snapshot.data ?? const <FoodItem>[];
                        if (items.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: _EmptyState(),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _ItemsTable(
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
                                    duration: const Duration(milliseconds: 260),
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
    int dailyGoal,
    int total,
  ) {
    return LabeledProgressBar(
      label: 'Calories',
      value: total.toDouble(),
      goal: dailyGoal.toDouble(),
      unit: 'kcal',
      color: AppColors.calories,
      overGoalColor: const Color(0xFF7F1D1D),
      height: _progressBarHeight,
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({
    required this.items,
    required this.onItemTap,
  });

  final List<FoodItem> items;
  final Future<void> Function(FoodItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _ItemsHeaderRow(textTheme: Theme.of(context).textTheme),
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
    required this.fat,
    required this.fatGoal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.height,
  });

  final double fat;
  final double fatGoal;
  final double protein;
  final double proteinGoal;
  final double carbs;
  final double carbsGoal;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LabeledProgressBar(
            label: 'Fat',
            value: fat,
            goal: fatGoal,
            color: AppColors.fat,
            height: height,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LabeledProgressBar(
            label: 'Protein',
            value: protein,
            goal: proteinGoal,
            color: AppColors.protein,
            height: height,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LabeledProgressBar(
            label: 'Carbs',
            value: carbs,
            goal: carbsGoal,
            color: AppColors.carbs,
            height: height,
          ),
        ),
      ],
    );
  }
}

class _ItemsHeaderRow extends StatelessWidget {
  const _ItemsHeaderRow({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text('Food', style: textTheme.labelLarge),
          ),
          Expanded(
            flex: 3,
            child: Text('Amount', style: textTheme.labelLarge),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Calories',
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('No entries for this day yet. Tap Add to log food.'),
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
