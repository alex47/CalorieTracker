class AppSettings {
  const AppSettings({
    required this.languageCode,
    required this.model,
    required this.reasoningEffort,
    required this.maxOutputTokens,
    required this.openAiTimeoutSeconds,
    required this.dailyGoal,
    required this.dailyFatGoal,
    required this.dailyProteinGoal,
    required this.dailyCarbsGoal,
  });

  final String languageCode;
  final String model;
  final String reasoningEffort;
  final int maxOutputTokens;
  final int openAiTimeoutSeconds;
  final int dailyGoal;
  final int dailyFatGoal;
  final int dailyProteinGoal;
  final int dailyCarbsGoal;
}
