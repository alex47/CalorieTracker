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
  final String notes;

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  factory FoodItem.fromMap(Map<String, Object?> map) {
    return FoodItem(
      id: map['id'] as int,
      entryId: map['entry_id'] as int,
      name: map['name'] as String,
      amount: map['amount'] as String,
      calories: map['calories'] as int,
      fat: _toDouble(map['fat']),
      protein: _toDouble(map['protein']),
      carbs: _toDouble(map['carbs']),
      notes: (map['notes'] as String?) ?? '',
    );
  }
}
