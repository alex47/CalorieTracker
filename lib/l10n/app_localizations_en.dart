// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Calorie Tracker';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get aboutTitle => 'About';

  @override
  String get addButton => 'Add';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get acceptButton => 'Accept';

  @override
  String get deleteButton => 'Delete';

  @override
  String get reestimateButton => 'Re-estimate';

  @override
  String get caloriesLabel => 'Calories';

  @override
  String get fatLabel => 'Fat';

  @override
  String get proteinLabel => 'Protein';

  @override
  String get carbsLabel => 'Carbs';

  @override
  String get foodLabel => 'Food';

  @override
  String get amountLabel => 'Amount';

  @override
  String get notesLabel => 'Notes';

  @override
  String caloriesKcalValue(Object calories) {
    return '$calories kcal';
  }

  @override
  String gramsValue(Object value) {
    return '$value g';
  }

  @override
  String get failedToLoadDailyTotals => 'Failed to load daily totals.';

  @override
  String get trackedFoods => 'Tracked foods';

  @override
  String get failedToLoadEntries => 'Failed to load entries.';

  @override
  String get emptyEntriesHint =>
      'No entries for this day yet. Tap Add to log food.';

  @override
  String get openAiSectionTitle => 'OpenAI';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHungarian => 'Hungarian';

  @override
  String get openAiApiKeyLabel => 'OpenAI API key';

  @override
  String get testKeyButton => 'Test key';

  @override
  String get modelLabel => 'Model';

  @override
  String get reasoningEffortLabel => 'Reasoning effort';

  @override
  String get maxOutputTokensLabel => 'Max output tokens';

  @override
  String get goalsSectionTitle => 'Goals';

  @override
  String get dailyCalorieGoalLabel => 'Daily calorie goal (kcal)';

  @override
  String get dailyFatGoalLabel => 'Daily fat goal (g)';

  @override
  String get dailyProteinGoalLabel => 'Daily protein goal (g)';

  @override
  String get dailyCarbsGoalLabel => 'Daily carbs goal (g)';

  @override
  String get dataToolsSectionTitle => 'Data tools';

  @override
  String get exportDataButton => 'Export data';

  @override
  String get importDataButton => 'Import data';

  @override
  String get exportComingSoon => 'Export is coming soon.';

  @override
  String get importComingSoon => 'Import is coming soon.';

  @override
  String couldNotLoadModels(Object error) {
    return 'Could not load models dynamically. $error';
  }

  @override
  String get enterApiKeyFirst => 'Please enter an API key first.';

  @override
  String get apiKeyTestSucceeded => 'API key test succeeded. Key saved.';

  @override
  String apiKeyTestFailed(Object error) {
    return 'API key test failed: $error';
  }

  @override
  String get setApiKeyInSettings =>
      'Please set your OpenAI API key in Settings.';

  @override
  String failedToFetchCalories(Object error) {
    return 'Failed to fetch calories. $error';
  }

  @override
  String get requestCaloriesBeforeSaving =>
      'Please request calories before saving.';

  @override
  String get addFoodTitle => 'Add food';

  @override
  String get foodAndAmountsLabel => 'Food and amounts';

  @override
  String get enterFoodItems => 'Please enter food items.';

  @override
  String get estimateCaloriesButton => 'Estimate calories';

  @override
  String get missingItemInAiResponse => 'Missing item in AI response.';

  @override
  String get invalidReestimatedItemInAiResponse =>
      'Invalid re-estimated item in AI response.';

  @override
  String failedToReestimateItem(Object error) {
    return 'Failed to re-estimate item. $error';
  }

  @override
  String failedToSaveItem(Object error) {
    return 'Failed to save item. $error';
  }

  @override
  String get deleteItemTitle => 'Delete item';

  @override
  String get deleteItemConfirmMessage =>
      'Are you sure you want to delete this food item?';

  @override
  String failedToDeleteItem(Object error) {
    return 'Failed to delete item. $error';
  }

  @override
  String failedToCopyItem(Object error) {
    return 'Failed to copy item. $error';
  }

  @override
  String get foodDetailsTitle => 'Food details';

  @override
  String get copyToTodayButton => 'Copy to today';

  @override
  String get askFollowupChangesLabel => 'Ask for follow-up changes';

  @override
  String get couldNotOpenGithubLink => 'Could not open GitHub link.';

  @override
  String updateCheckFailed(Object error) {
    return 'Update check failed: $error';
  }

  @override
  String get noApkAssetFound => 'No APK asset found in latest release.';

  @override
  String get couldNotOpenUpdateUrl => 'Could not open update download URL.';

  @override
  String updateInstallFailed(Object error) {
    return 'Update install failed: $error';
  }

  @override
  String get installerOpenedMessage =>
      'Installer opened. If prompted, allow installs from this app.';

  @override
  String get aboutDescription =>
      'Calorie Tracker helps you log meals and estimate calories using OpenAI.';

  @override
  String versionLabel(Object version) {
    return 'Version: $version';
  }

  @override
  String get checkForUpdatesButton => 'Check for updates';

  @override
  String updateAvailableStatus(Object latestVersion, Object currentVersion) {
    return 'Update available: $latestVersion (current: $currentVersion)';
  }

  @override
  String upToDateStatus(Object currentVersion) {
    return 'You are up to date ($currentVersion).';
  }

  @override
  String get installLatestApkButton => 'Install latest APK';

  @override
  String get downloadingUpdate => 'Downloading update...';

  @override
  String downloadingUpdateProgress(Object percent) {
    return 'Downloading update... $percent%';
  }

  @override
  String get githubRepositoryButton => 'GitHub repository';

  @override
  String get errorOpenAiRequestTimedOut => 'OpenAI request timed out.';

  @override
  String get errorOpenAiRequestFailed => 'OpenAI request failed.';

  @override
  String get errorNoModelsReturned =>
      'No models were returned for this API key.';

  @override
  String get errorFailedParseAiResponse => 'Failed to parse AI response.';

  @override
  String get errorEmptyAiContent => 'AI returned an empty response.';

  @override
  String get errorAiNoItemsNoExplanation =>
      'AI returned no items and no explanation.';

  @override
  String get errorMissingNameOrAmount => 'Missing food name or amount.';

  @override
  String get errorMissingOrInvalidCalories => 'Missing or invalid calories.';

  @override
  String get errorMissingOrInvalidFat => 'Missing or invalid fat.';

  @override
  String get errorMissingOrInvalidProtein => 'Missing or invalid protein.';

  @override
  String get errorMissingOrInvalidCarbs => 'Missing or invalid carbs.';

  @override
  String get errorUpdateCheckTimedOut => 'Update check timed out.';

  @override
  String get errorUpdateCheckFailed => 'Update check failed.';

  @override
  String get errorLatestReleaseTagMissing => 'Latest release tag is missing.';

  @override
  String get errorApkDownloadFailed => 'APK download failed.';

  @override
  String get errorCouldNotOpenInstaller => 'Could not open installer.';
}
