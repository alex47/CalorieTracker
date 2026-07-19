import 'package:calorie_tracker/models/food_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FoodItem calculations', () {
    test('calculates quantity ratios, calories, and macros', () {
      expect(
        FoodItem.multiplierRatio(
          multiplier: 250,
          standardUnitAmount: 100,
        ),
        2.5,
      );
      expect(
        FoodItem.computeCalories(
          standardCalories: 52,
          multiplier: 250,
          standardUnitAmount: 100,
        ),
        130,
      );
      expect(
        FoodItem.computeMacro(
          standardMacro: 14,
          multiplier: 250,
          standardUnitAmount: 100,
        ),
        35,
      );
    });

    test('invalid multipliers and standard amounts fall back to one', () {
      expect(
        FoodItem.multiplierRatio(
          multiplier: 0,
          standardUnitAmount: -1,
        ),
        1,
      );
    });

    test('formats standard and calculated amounts', () {
      expect(_item().standardAmountText, '100 g');
      expect(
          _item(multiplier: 2.25, standardUnit: 'piece').calculatedAmountText,
          '2.3 piece');
      expect(_item(multiplier: 2, standardUnit: 'piece').calculatedAmountText,
          '2 piece');
      expect(
        _item(amount: 'legacy', standardUnit: '100 g').calculatedAmountText,
        'legacy',
      );
      expect(
        _item(amount: 'fallback', standardUnit: '').calculatedAmountText,
        'fallback',
      );
    });
  });

  group('FoodItem map conversion', () {
    test('parses current rows and numeric types', () {
      final item = FoodItem.fromMap({
        'id': 1,
        'entry_id': 2,
        'food_id': 3,
        'name': 'Apple',
        'amount': '250 g',
        'calories': 130.4,
        'fat': 0.5,
        'protein': 1,
        'carbs': 35,
        'standard_amount': '100 g',
        'standard_unit': 'g',
        'standard_unit_amount': 100,
        'multiplier': 250,
        'standard_calories': 52,
        'standard_fat': 0.2,
        'standard_protein': 0.4,
        'standard_carbs': 14,
        'notes': 'Synthetic',
      });

      expect(item.id, 1);
      expect(item.entryId, 2);
      expect(item.foodId, 3);
      expect(item.calories, 130);
      expect(item.standardUnit, 'g');
      expect(item.standardUnitAmount, 100);
      expect(item.multiplier, 250);
      expect(item.calculatedAmountText, '250 g');
    });

    test('parses legacy standard amounts with comma decimals', () {
      final item = FoodItem.fromMap({
        'id': 1,
        'entry_id': 2,
        'name': 'Legacy',
        'amount': 'fallback amount',
        'calories': 100,
        'fat': 1,
        'protein': 2,
        'carbs': 3,
        'standard_amount': '100,5 ml',
        'multiplier': 0,
      });

      expect(item.foodId, 0);
      expect(item.standardUnit, 'ml');
      expect(item.standardUnitAmount, 100.5);
      expect(item.multiplier, 1);
      expect(item.standardCalories, 100);
      expect(item.standardFat, 1);
      expect(item.standardProtein, 2);
      expect(item.standardCarbs, 3);
    });

    test('falls back safely for malformed legacy amounts', () {
      final item = FoodItem.fromMap({
        'id': 1,
        'entry_id': 2,
        'name': 'Legacy',
        'amount': 'one bowl',
        'calories': 100,
        'standard_amount': '',
        'standard_unit_amount': 0,
        'multiplier': -2,
      });

      expect(item.standardUnit, 'one bowl');
      expect(item.standardUnitAmount, 1);
      expect(item.multiplier, 1);
    });

    test('copyWith changes requested values and retains the rest', () {
      final original = _item();
      final changed = original.copyWith(name: 'Changed', multiplier: 250);

      expect(changed.name, 'Changed');
      expect(changed.multiplier, 250);
      expect(changed.id, original.id);
      expect(changed.standardCalories, original.standardCalories);
    });
  });
}

FoodItem _item({
  String amount = '100 g',
  String standardUnit = 'g',
  double multiplier = 100,
}) {
  return FoodItem(
    id: 1,
    entryId: 2,
    foodId: 3,
    name: 'Apple',
    amount: amount,
    calories: 52,
    fat: 0.2,
    protein: 0.4,
    carbs: 14,
    standardUnit: standardUnit,
    standardUnitAmount: 100,
    multiplier: multiplier,
    standardCalories: 52,
    standardFat: 0.2,
    standardProtein: 0.4,
    standardCarbs: 14,
    notes: '',
  );
}
