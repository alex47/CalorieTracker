class FoodDefinition {
  const FoodDefinition({
    required this.id,
    required this.name,
    required this.standardUnit,
    required this.standardUnitAmount,
    required this.standardCalories,
    required this.standardFat,
    required this.standardProtein,
    required this.standardCarbs,
    required this.notes,
    required this.createdAtIso,
    required this.updatedAtIso,
    required this.isVisibleInLibrary,
    this.usageCount = 0,
  });

  final int id;
  final String name;
  final String standardUnit;
  final double standardUnitAmount;
  final double standardCalories;
  final double standardFat;
  final double standardProtein;
  final double standardCarbs;
  final String notes;
  final String createdAtIso;
  final String updatedAtIso;
  final bool isVisibleInLibrary;
  final int usageCount;

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  factory FoodDefinition.fromMap(Map<String, Object?> row) {
    return FoodDefinition(
      id: row['id'] as int,
      name: (row['name'] as String?) ?? '',
      standardUnit: (row['standard_unit'] as String?) ?? '',
      standardUnitAmount: _toDouble(row['standard_unit_amount']),
      standardCalories: _toDouble(row['standard_calories']),
      standardFat: _toDouble(row['standard_fat']),
      standardProtein: _toDouble(row['standard_protein']),
      standardCarbs: _toDouble(row['standard_carbs']),
      notes: (row['notes'] as String?) ?? '',
      createdAtIso: (row['created_at'] as String?) ?? '',
      updatedAtIso: (row['updated_at'] as String?) ?? '',
      isVisibleInLibrary: ((row['is_visible_in_library'] as num?)?.toInt() ?? 1) == 1,
      usageCount: (row['usage_count'] as num?)?.toInt() ?? 0,
    );
  }

  FoodDefinition copyWith({
    int? id,
    String? name,
    String? standardUnit,
    double? standardUnitAmount,
    double? standardCalories,
    double? standardFat,
    double? standardProtein,
    double? standardCarbs,
    String? notes,
    String? createdAtIso,
    String? updatedAtIso,
    bool? isVisibleInLibrary,
    int? usageCount,
  }) {
    return FoodDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      standardUnit: standardUnit ?? this.standardUnit,
      standardUnitAmount: standardUnitAmount ?? this.standardUnitAmount,
      standardCalories: standardCalories ?? this.standardCalories,
      standardFat: standardFat ?? this.standardFat,
      standardProtein: standardProtein ?? this.standardProtein,
      standardCarbs: standardCarbs ?? this.standardCarbs,
      notes: notes ?? this.notes,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      isVisibleInLibrary: isVisibleInLibrary ?? this.isVisibleInLibrary,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}
