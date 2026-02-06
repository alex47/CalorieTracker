import 'package:flutter/material.dart';

import '../main.dart';
import '../models/food_item.dart';
import '../services/entries_repository.dart';
import '../services/settings_service.dart';
import 'about_screen.dart';
import 'add_entry_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  List<FoodItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final items = await EntriesRepository.instance.fetchItemsForDate(_selectedDate);
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  int _totalCalories() {
    return _items.fold<int>(0, (sum, item) => sum + item.calories);
  }

  void _shiftDate(int offsetDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offsetDays));
    });
    _loadItems();
  }

  Future<void> _navigateToAdd() async {
    await Navigator.pushNamed(
      context,
      AddEntryScreen.routeName,
      arguments: _selectedDate,
    );
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final dailyGoal = SettingsService.instance.settings.dailyGoal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calorie Tracker'),
        actions: [
          PopupMenuButton<String>(
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
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) {
            return;
          }
          if (details.primaryVelocity! < 0) {
            _shiftDate(1);
          } else if (details.primaryVelocity! > 0) {
            _shiftDate(-1);
          }
        },
        child: RefreshIndicator(
          onRefresh: _loadItems,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                formatDate(_selectedDate),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _buildTotalCard(dailyGoal),
              const SizedBox(height: 16),
              Text(
                'Food items',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_items.isEmpty)
                const _EmptyState()
              else
                _ItemsTable(items: _items),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard(int dailyGoal) {
    final total = _totalCalories();
    final remaining = dailyGoal - total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total calories', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '$total kcal',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Daily goal: $dailyGoal kcal (${remaining >= 0 ? remaining : 0} kcal remaining)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({required this.items});

  final List<FoodItem> items;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Food')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Calories')),
          DataColumn(label: Text('Notes')),
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(item.name)),
                  DataCell(Text(item.amount)),
                  DataCell(Text('${item.calories}')),
                  DataCell(Text(item.notes.isEmpty ? '-' : item.notes)),
                ],
              ),
            )
            .toList(),
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
