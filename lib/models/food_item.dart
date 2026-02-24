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
    required this.standardAmount,
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
  final String standardAmount;
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

  static int computeCalories({
    required double standardCalories,
    required double multiplier,
  }) {
    return (standardCalories * multiplier).round();
  }

  static double computeMacro({
    required double standardMacro,
    required double multiplier,
  }) {
    return standardMacro * multiplier;
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
    String? standardAmount,
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
      standardAmount: standardAmount ?? this.standardAmount,
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
    final standardAmount = (map['standard_amount'] as String?)?.trim();
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
      standardAmount: standardAmount == null || standardAmount.isEmpty
          ? (map['amount'] as String)
          : standardAmount,
      multiplier: multiplier,
      standardCalories: standardCalories,
      standardFat: standardFat,
      standardProtein: standardProtein,
      standardCarbs: standardCarbs,
      notes: (map['notes'] as String?) ?? '',
    );
  }
}
