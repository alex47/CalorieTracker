import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_colors.dart';
import '../widgets/labeled_group_box.dart';

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
          Wrap(
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
          ),
        ],
      ),
    );
  }
}
