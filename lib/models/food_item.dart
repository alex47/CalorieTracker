class FoodItem {
  FoodItem({
    required this.id,
    required this.entryId,
    required this.name,
    required this.amount,
    required this.calories,
    required this.notes,
  });

  final int id;
  final int entryId;
  final String name;
  final String amount;
  final int calories;
  final String notes;

  factory FoodItem.fromMap(Map<String, Object?> map) {
    return FoodItem(
      id: map['id'] as int,
      entryId: map['entry_id'] as int,
      name: map['name'] as String,
      amount: map['amount'] as String,
      calories: map['calories'] as int,
      notes: (map['notes'] as String?) ?? '',
    );
  }
}
