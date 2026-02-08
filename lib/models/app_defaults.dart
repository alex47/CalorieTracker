class AppDefaults {
  const AppDefaults._();

  static const String model = 'gpt-5-mini';
  static const String reasoningEffort = 'low';
  static const List<String> reasoningEffortOptions = ['minimal', 'low', 'medium', 'high'];

  static const int minOutputTokens = 16;
  static const int maxOutputTokens = 5000;

  static const int dailyCalories = 2000;
  static const int dailyFatGrams = 70;
  static const int dailyProteinGrams = 150;
  static const int dailyCarbsGrams = 250;
}
