import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../main.dart';
import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/labeled_group_box.dart';
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
    final dailyGoal = SettingsService.instance.settings.dailyGoal;
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      formatDate(pageDate),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<FoodItem>>(
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
                              protein: _totalProtein(items),
                              carbs: _totalCarbs(items),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tracked foods',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<FoodItem>>(
                      future: _itemsForDate(pageDate),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Failed to load entries.',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          );
                        }
                        final items = snapshot.data ?? const <FoodItem>[];
                        if (items.isEmpty) {
                          return const _EmptyState();
                        }
                        return _ItemsTable(
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
    final progress = dailyGoal > 0 ? (total / dailyGoal).clamp(0.0, 1.0) : 0.0;
    final isOverGoal = total > dailyGoal;
    const overGoalColor = Color(0xFF7F1D1D);
    final barColor = isOverGoal ? overGoalColor : Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 76,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 76,
                color: barColor,
              ),
            ),
            SizedBox(
              height: 76,
              child: Center(
                child: Text(
                  '$total kcal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
          ],
        ),
      ),
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
    required this.protein,
    required this.carbs,
  });

  final double fat;
  final double protein;
  final double carbs;

  String _format(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        MetricGroupBox(
          label: 'Fat',
          value: '${_format(fat)} g',
          color: AppColors.fat,
        ),
        MetricGroupBox(
          label: 'Protein',
          value: '${_format(protein)} g',
          color: AppColors.protein,
        ),
        MetricGroupBox(
          label: 'Carbs',
          value: '${_format(carbs)} g',
          color: AppColors.carbs,
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
