class FoodItem {
  FoodItem({
    required this.id,
    required this.entryId,
    required this.name,
    required this.amount,
    required this.calories,
    required this.fat,
    required this.protein,
    required this.carbs,
    required this.standardUnit,
    required this.standardUnitAmount,
    required this.multiplier,
    required this.standardCalories,
    required this.standardFat,
    required this.standardProtein,
    required this.standardCarbs,
    required this.notes,
  });

  final int id;
  final int entryId;
  final String name;
  final String amount;
  final int calories;
  final double fat;
  final double protein;
  final double carbs;
  final String standardUnit;
  final double standardUnitAmount;
  final double multiplier;
  final double standardCalories;
  final double standardFat;
  final double standardProtein;
  final double standardCarbs;
  final String notes;

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static ({double amount, String unit}) _parseLegacyStandardAmount(
    String standardAmount,
    String fallbackAmountText,
  ) {
    final trimmed = standardAmount.trim();
    if (trimmed.isEmpty) {
      return (amount: 1.0, unit: fallbackAmountText);
    }
    final match = RegExp(r'^\s*([0-9]+(?:[.,][0-9]+)?)\s*(.+?)\s*$').firstMatch(trimmed);
    if (match == null) {
      return (amount: 1.0, unit: trimmed);
    }
    final parsedAmount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    final unit = match.group(2)!.trim();
    if (parsedAmount == null || parsedAmount <= 0 || unit.isEmpty) {
      return (amount: 1.0, unit: trimmed);
    }
    return (amount: parsedAmount, unit: unit);
  }

  static String _formatAmountValue(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    final oneDecimal = value.toStringAsFixed(1);
    if (oneDecimal.endsWith('.0')) {
      return oneDecimal.substring(0, oneDecimal.length - 2);
    }
    return oneDecimal;
  }

  String get standardAmountText {
    final amountText = standardUnitAmount % 1 == 0
        ? standardUnitAmount.toInt().toString()
        : standardUnitAmount.toString();
    return '$amountText $standardUnit';
  }

  String get calculatedAmountText {
    final unit = standardUnit.trim();
    if (unit.isEmpty) {
      return amount;
    }
    // Legacy rows may still carry a combined value like "100 g" in standardUnit.
    if (RegExp(r'\d').hasMatch(unit)) {
      return amount;
    }
    final resolvedMultiplier = multiplier > 0 ? multiplier : 1.0;
    return '${_formatAmountValue(resolvedMultiplier)} $unit';
  }

  static double multiplierRatio({
    required double multiplier,
    required double standardUnitAmount,
  }) {
    final resolvedMultiplier = multiplier > 0 ? multiplier : 1.0;
    final resolvedStandardUnitAmount = standardUnitAmount > 0 ? standardUnitAmount : 1.0;
    return resolvedMultiplier / resolvedStandardUnitAmount;
  }

  static int computeCalories({
    required double standardCalories,
    required double multiplier,
    required double standardUnitAmount,
  }) {
    final ratio = multiplierRatio(
      multiplier: multiplier,
      standardUnitAmount: standardUnitAmount,
    );
    return (standardCalories * ratio).round();
  }

  static double computeMacro({
    required double standardMacro,
    required double multiplier,
    required double standardUnitAmount,
  }) {
    final ratio = multiplierRatio(
      multiplier: multiplier,
      standardUnitAmount: standardUnitAmount,
    );
    return standardMacro * ratio;
  }

  FoodItem copyWith({
    int? id,
    int? entryId,
    String? name,
    String? amount,
    int? calories,
    double? fat,
    double? protein,
    double? carbs,
    String? standardUnit,
    double? standardUnitAmount,
    double? multiplier,
    double? standardCalories,
    double? standardFat,
    double? standardProtein,
    double? standardCarbs,
    String? notes,
  }) {
    return FoodItem(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      calories: calories ?? this.calories,
      fat: fat ?? this.fat,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      standardUnit: standardUnit ?? this.standardUnit,
      standardUnitAmount: standardUnitAmount ?? this.standardUnitAmount,
      multiplier: multiplier ?? this.multiplier,
      standardCalories: standardCalories ?? this.standardCalories,
      standardFat: standardFat ?? this.standardFat,
      standardProtein: standardProtein ?? this.standardProtein,
      standardCarbs: standardCarbs ?? this.standardCarbs,
      notes: notes ?? this.notes,
    );
  }

  factory FoodItem.fromMap(Map<String, Object?> map) {
    final calories = map['calories'] is int
        ? map['calories'] as int
        : ((map['calories'] as num?)?.round() ?? 0);
    final fat = _toDouble(map['fat']);
    final protein = _toDouble(map['protein']);
    final carbs = _toDouble(map['carbs']);
    final multiplierRaw = _toDouble(map['multiplier']);
    final multiplier = multiplierRaw > 0 ? multiplierRaw : 1.0;
    final standardAmount = (map['standard_amount'] as String?)?.trim() ?? '';
    final standardUnitRaw = (map['standard_unit'] as String?)?.trim();
    final standardUnitAmountRaw = map['standard_unit_amount'] is num
        ? (map['standard_unit_amount'] as num).toDouble()
        : null;
    final fallbackParsed = _parseLegacyStandardAmount(
      standardAmount,
      map['amount'] as String,
    );
    final standardCalories = map['standard_calories'] is num
        ? (map['standard_calories'] as num).toDouble()
        : calories.toDouble();
    final standardFat = map['standard_fat'] is num
        ? (map['standard_fat'] as num).toDouble()
        : fat;
    final standardProtein = map['standard_protein'] is num
        ? (map['standard_protein'] as num).toDouble()
        : protein;
    final standardCarbs = map['standard_carbs'] is num
        ? (map['standard_carbs'] as num).toDouble()
        : carbs;
    return FoodItem(
      id: map['id'] as int,
      entryId: map['entry_id'] as int,
      name: map['name'] as String,
      amount: map['amount'] as String,
      calories: calories,
      fat: fat,
      protein: protein,
      carbs: carbs,
      standardUnit: (standardUnitRaw == null || standardUnitRaw.isEmpty)
          ? fallbackParsed.unit
          : standardUnitRaw,
      standardUnitAmount: standardUnitAmountRaw == null || standardUnitAmountRaw <= 0
          ? fallbackParsed.amount
          : standardUnitAmountRaw,
      multiplier: multiplier,
      standardCalories: standardCalories,
      standardFat: standardFat,
      standardProtein: standardProtein,
      standardCarbs: standardCarbs,
      notes: (map['notes'] as String?) ?? '',
    );
  }
}
