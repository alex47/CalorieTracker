import 'package:flutter/material.dart';

import '../main.dart';

class DailyMacrosScreen extends StatelessWidget {
  const DailyMacrosScreen({
    super.key,
    required this.date,
    required this.fat,
    required this.protein,
    required this.carbs,
  });

  final DateTime date;
  final double fat;
  final double protein;
  final double carbs;

  String _format(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily macros')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            formatDate(date),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _MacroCard(
            label: 'Fat',
            value: '${_format(fat)} g',
          ),
          const SizedBox(height: 10),
          _MacroCard(
            label: 'Protein',
            value: '${_format(protein)} g',
          ),
          const SizedBox(height: 10),
          _MacroCard(
            label: 'Carbs',
            value: '${_format(carbs)} g',
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
