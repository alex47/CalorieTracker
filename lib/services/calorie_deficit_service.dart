import '../models/metabolic_profile.dart';

class CalorieDeficitService {
  CalorieDeficitService._();

  static const Map<String, double> _activityFactors = {
    'bmr': 1.0,
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'very_active': 1.9,
  };

  static int maintenanceCalories(MetabolicProfile profile) {
    final isMale = profile.sex == 'male';
    final base = (10 * profile.weightKg) + (6.25 * profile.heightCm) - (5 * profile.age);
    final bmr = base + (isMale ? 5 : -161);
    final factor = _activityFactors[profile.activityLevel] ?? _activityFactors['moderate']!;
    return (bmr * factor).round();
  }

  static int dailyDeficit({
    required int consumedCalories,
    required MetabolicProfile profile,
  }) {
    return maintenanceCalories(profile) - consumedCalories;
  }
}
