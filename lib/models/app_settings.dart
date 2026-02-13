class AppSettings {
  const AppSettings({
    required this.languageCode,
    required this.model,
    required this.reasoningEffort,
    required this.maxOutputTokens,
    required this.openAiTimeoutSeconds,
  });

  final String languageCode;
  final String model;
  final String reasoningEffort;
  final int maxOutputTokens;
  final int openAiTimeoutSeconds;
}
