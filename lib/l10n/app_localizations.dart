import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hu')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Calorie Tracker'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @weeklySummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly summary'**
  String get weeklySummaryTitle;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @acceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @reestimateButton.
  ///
  /// In en, this message translates to:
  /// **'Re-estimate'**
  String get reestimateButton;

  /// No description provided for @caloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get caloriesLabel;

  /// No description provided for @fatLabel.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fatLabel;

  /// No description provided for @proteinLabel.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get proteinLabel;

  /// No description provided for @carbsLabel.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbsLabel;

  /// No description provided for @foodLabel.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get foodLabel;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @caloriesKcalValue.
  ///
  /// In en, this message translates to:
  /// **'{calories} kcal'**
  String caloriesKcalValue(Object calories);

  /// No description provided for @gramsValue.
  ///
  /// In en, this message translates to:
  /// **'{value} g'**
  String gramsValue(Object value);

  /// No description provided for @failedToLoadDailyTotals.
  ///
  /// In en, this message translates to:
  /// **'Failed to load daily totals.'**
  String get failedToLoadDailyTotals;

  /// No description provided for @trackedFoods.
  ///
  /// In en, this message translates to:
  /// **'Tracked foods'**
  String get trackedFoods;

  /// No description provided for @failedToLoadEntries.
  ///
  /// In en, this message translates to:
  /// **'Failed to load entries.'**
  String get failedToLoadEntries;

  /// No description provided for @emptyEntriesHint.
  ///
  /// In en, this message translates to:
  /// **'No entries for this day yet. Tap Add to log food.'**
  String get emptyEntriesHint;

  /// No description provided for @noEntriesForWeek.
  ///
  /// In en, this message translates to:
  /// **'No entries for this week.'**
  String get noEntriesForWeek;

  /// No description provided for @openAiSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenAI'**
  String get openAiSectionTitle;

  /// No description provided for @generalSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSectionTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageNameNative.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameNative;

  /// No description provided for @languageNameEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEnglish;

  /// No description provided for @openAiApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenAI API key'**
  String get openAiApiKeyLabel;

  /// No description provided for @testKeyButton.
  ///
  /// In en, this message translates to:
  /// **'Test key'**
  String get testKeyButton;

  /// No description provided for @modelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// No description provided for @reasoningEffortLabel.
  ///
  /// In en, this message translates to:
  /// **'Reasoning effort'**
  String get reasoningEffortLabel;

  /// No description provided for @maxOutputTokensLabel.
  ///
  /// In en, this message translates to:
  /// **'Max output tokens'**
  String get maxOutputTokensLabel;

  /// No description provided for @openAiTimeoutSecondsLabel.
  ///
  /// In en, this message translates to:
  /// **'Timeout (seconds)'**
  String get openAiTimeoutSecondsLabel;

  /// No description provided for @metabolicProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Metabolic profile'**
  String get metabolicProfileTitle;

  /// No description provided for @ageLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get ageLabel;

  /// No description provided for @sexLabel.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sexLabel;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @heightCmLabel.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCmLabel;

  /// No description provided for @weightKgLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKgLabel;

  /// No description provided for @activityLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity level'**
  String get activityLevelLabel;

  /// No description provided for @macroPresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get macroPresetLabel;

  /// No description provided for @macroPresetBalancedDefault.
  ///
  /// In en, this message translates to:
  /// **'Balanced default'**
  String get macroPresetBalancedDefault;

  /// No description provided for @macroPresetFatLossHigherProtein.
  ///
  /// In en, this message translates to:
  /// **'Fat loss (higher protein)'**
  String get macroPresetFatLossHigherProtein;

  /// No description provided for @macroPresetBodyRecompositionTraining.
  ///
  /// In en, this message translates to:
  /// **'Body recomposition / training'**
  String get macroPresetBodyRecompositionTraining;

  /// No description provided for @macroPresetEnduranceHighActivity.
  ///
  /// In en, this message translates to:
  /// **'Endurance / high activity'**
  String get macroPresetEnduranceHighActivity;

  /// No description provided for @macroPresetLowerCarbAppetiteControl.
  ///
  /// In en, this message translates to:
  /// **'Lower-carb appetite control'**
  String get macroPresetLowerCarbAppetiteControl;

  /// No description provided for @macroPresetHighCarbPerformance.
  ///
  /// In en, this message translates to:
  /// **'High-carb performance'**
  String get macroPresetHighCarbPerformance;

  /// No description provided for @activityBmr.
  ///
  /// In en, this message translates to:
  /// **'BMR (resting)'**
  String get activityBmr;

  /// No description provided for @activitySedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get activitySedentary;

  /// No description provided for @activityLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get activityLight;

  /// No description provided for @activityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get activityModerate;

  /// No description provided for @activityActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activityActive;

  /// No description provided for @activityVeryActive.
  ///
  /// In en, this message translates to:
  /// **'Very active'**
  String get activityVeryActive;

  /// No description provided for @setMetabolicProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Set your metabolic profile to track calorie deficit.'**
  String get setMetabolicProfileHint;

  /// No description provided for @dailyDeficitLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily deficit: {deficit} kcal'**
  String dailyDeficitLabel(Object deficit);

  /// No description provided for @dailyDeficitTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily deficit'**
  String get dailyDeficitTitle;

  /// No description provided for @maintenanceCaloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Maintenance: {calories} kcal/day'**
  String maintenanceCaloriesLabel(Object calories);

  /// No description provided for @dataToolsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Data tools'**
  String get dataToolsSectionTitle;

  /// No description provided for @exportDataButton.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportDataButton;

  /// No description provided for @importDataButton.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get importDataButton;

  /// No description provided for @exportIncludeApiKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export API key?'**
  String get exportIncludeApiKeyDialogTitle;

  /// No description provided for @exportIncludeApiKeyDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to include your OpenAI API key in the exported file?\n\nWarning: this stores the key in plain text.'**
  String get exportIncludeApiKeyDialogBody;

  /// No description provided for @exportWithoutApiKeyButton.
  ///
  /// In en, this message translates to:
  /// **'Without API key'**
  String get exportWithoutApiKeyButton;

  /// No description provided for @exportWithApiKeyButton.
  ///
  /// In en, this message translates to:
  /// **'With API key'**
  String get exportWithApiKeyButton;

  /// No description provided for @importApiKeyDetectedDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'API key found in backup'**
  String get importApiKeyDetectedDialogTitle;

  /// No description provided for @importApiKeyDetectedDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This backup contains an OpenAI API key. Do you want to overwrite the current API key on this device?'**
  String get importApiKeyDetectedDialogBody;

  /// No description provided for @importOverwriteApiKeyButton.
  ///
  /// In en, this message translates to:
  /// **'Overwrite API key'**
  String get importOverwriteApiKeyButton;

  /// No description provided for @importKeepCurrentApiKeyButton.
  ///
  /// In en, this message translates to:
  /// **'Keep current API key'**
  String get importKeepCurrentApiKeyButton;

  /// No description provided for @exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled.'**
  String get exportCancelled;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data exported: {path}'**
  String exportSuccess(Object path);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(Object error);

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data imported: {entriesCount} entries, {itemsCount} food items.'**
  String importSuccess(Object entriesCount, Object itemsCount);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(Object error);

  /// No description provided for @exportComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Export is coming soon.'**
  String get exportComingSoon;

  /// No description provided for @importComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Import is coming soon.'**
  String get importComingSoon;

  /// No description provided for @couldNotLoadModels.
  ///
  /// In en, this message translates to:
  /// **'Could not load models dynamically. {error}'**
  String couldNotLoadModels(Object error);

  /// No description provided for @enterApiKeyFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enter an API key first.'**
  String get enterApiKeyFirst;

  /// No description provided for @apiKeyTestSucceeded.
  ///
  /// In en, this message translates to:
  /// **'API key test succeeded. Key saved.'**
  String get apiKeyTestSucceeded;

  /// No description provided for @apiKeyTestFailed.
  ///
  /// In en, this message translates to:
  /// **'API key test failed: {error}'**
  String apiKeyTestFailed(Object error);

  /// No description provided for @setApiKeyInSettings.
  ///
  /// In en, this message translates to:
  /// **'Please set your OpenAI API key in Settings.'**
  String get setApiKeyInSettings;

  /// No description provided for @failedToFetchCalories.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch calories. {error}'**
  String failedToFetchCalories(Object error);

  /// No description provided for @requestCaloriesBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Please request calories before saving.'**
  String get requestCaloriesBeforeSaving;

  /// No description provided for @addFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Add food'**
  String get addFoodTitle;

  /// No description provided for @foodAndAmountsLabel.
  ///
  /// In en, this message translates to:
  /// **'Food and amounts'**
  String get foodAndAmountsLabel;

  /// No description provided for @enterFoodItems.
  ///
  /// In en, this message translates to:
  /// **'Please enter food items.'**
  String get enterFoodItems;

  /// No description provided for @estimateCaloriesButton.
  ///
  /// In en, this message translates to:
  /// **'Estimate calories'**
  String get estimateCaloriesButton;

  /// No description provided for @missingItemInAiResponse.
  ///
  /// In en, this message translates to:
  /// **'Missing item in AI response.'**
  String get missingItemInAiResponse;

  /// No description provided for @invalidReestimatedItemInAiResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid re-estimated item in AI response.'**
  String get invalidReestimatedItemInAiResponse;

  /// No description provided for @failedToReestimateItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to re-estimate item. {error}'**
  String failedToReestimateItem(Object error);

  /// No description provided for @failedToSaveItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to save item. {error}'**
  String failedToSaveItem(Object error);

  /// No description provided for @deleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get deleteItemTitle;

  /// No description provided for @deleteItemConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this food item?'**
  String get deleteItemConfirmMessage;

  /// No description provided for @failedToDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete item. {error}'**
  String failedToDeleteItem(Object error);

  /// No description provided for @failedToCopyItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy item. {error}'**
  String failedToCopyItem(Object error);

  /// No description provided for @foodDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Food details'**
  String get foodDetailsTitle;

  /// No description provided for @copyToTodayButton.
  ///
  /// In en, this message translates to:
  /// **'Copy to today'**
  String get copyToTodayButton;

  /// No description provided for @showAiResponseButton.
  ///
  /// In en, this message translates to:
  /// **'Show AI response'**
  String get showAiResponseButton;

  /// No description provided for @aiResponseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'AI response'**
  String get aiResponseDialogTitle;

  /// No description provided for @copyAiResponseButton.
  ///
  /// In en, this message translates to:
  /// **'Copy response'**
  String get copyAiResponseButton;

  /// No description provided for @aiResponseCopiedMessage.
  ///
  /// In en, this message translates to:
  /// **'AI response copied.'**
  String get aiResponseCopiedMessage;

  /// No description provided for @askFollowupChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'Ask for follow-up changes'**
  String get askFollowupChangesLabel;

  /// No description provided for @couldNotOpenGithubLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open GitHub link.'**
  String get couldNotOpenGithubLink;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed: {error}'**
  String updateCheckFailed(Object error);

  /// No description provided for @noApkAssetFound.
  ///
  /// In en, this message translates to:
  /// **'No APK asset found in latest release.'**
  String get noApkAssetFound;

  /// No description provided for @couldNotOpenUpdateUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not open update download URL.'**
  String get couldNotOpenUpdateUrl;

  /// No description provided for @updateInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Update install failed: {error}'**
  String updateInstallFailed(Object error);

  /// No description provided for @installerOpenedMessage.
  ///
  /// In en, this message translates to:
  /// **'Installer opened. If prompted, allow installs from this app.'**
  String get installerOpenedMessage;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Calorie Tracker helps you log meals and estimate calories using OpenAI.'**
  String get aboutDescription;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String versionLabel(Object version);

  /// No description provided for @checkForUpdatesButton.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdatesButton;

  /// No description provided for @updateAvailableDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableDialogTitle;

  /// No description provided for @updateAvailableDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Version {latestVersion} is available.'**
  String updateAvailableDialogBody(Object latestVersion);

  /// No description provided for @updateAvailableDialogLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateAvailableDialogLater;

  /// No description provided for @updateAvailableDialogView.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateAvailableDialogView;

  /// No description provided for @updateAvailableStatus.
  ///
  /// In en, this message translates to:
  /// **'New version available: {latestVersion}'**
  String updateAvailableStatus(Object latestVersion);

  /// No description provided for @upToDateStatus.
  ///
  /// In en, this message translates to:
  /// **'You are up to date.'**
  String get upToDateStatus;

  /// No description provided for @installLatestApkButton.
  ///
  /// In en, this message translates to:
  /// **'Install latest APK'**
  String get installLatestApkButton;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update...'**
  String get downloadingUpdate;

  /// No description provided for @downloadingUpdateProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading update... {percent}%'**
  String downloadingUpdateProgress(Object percent);

  /// No description provided for @githubRepositoryButton.
  ///
  /// In en, this message translates to:
  /// **'GitHub repository'**
  String get githubRepositoryButton;

  /// No description provided for @errorOpenAiRequestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'OpenAI request timed out.'**
  String get errorOpenAiRequestTimedOut;

  /// No description provided for @errorOpenAiRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'OpenAI request failed.'**
  String get errorOpenAiRequestFailed;

  /// No description provided for @errorNoModelsReturned.
  ///
  /// In en, this message translates to:
  /// **'No models were returned for this API key.'**
  String get errorNoModelsReturned;

  /// No description provided for @aiSaysPrefix.
  ///
  /// In en, this message translates to:
  /// **'The AI says: {message}'**
  String aiSaysPrefix(Object message);

  /// No description provided for @errorFailedParseAiResponse.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse AI response.'**
  String get errorFailedParseAiResponse;

  /// No description provided for @errorEmptyAiContent.
  ///
  /// In en, this message translates to:
  /// **'AI returned an empty response.'**
  String get errorEmptyAiContent;

  /// No description provided for @errorAiNoItemsNoExplanation.
  ///
  /// In en, this message translates to:
  /// **'AI returned no items and no explanation.'**
  String get errorAiNoItemsNoExplanation;

  /// No description provided for @errorMissingNameOrAmount.
  ///
  /// In en, this message translates to:
  /// **'Missing food name or amount.'**
  String get errorMissingNameOrAmount;

  /// No description provided for @errorMissingOrInvalidCalories.
  ///
  /// In en, this message translates to:
  /// **'Missing or invalid calories.'**
  String get errorMissingOrInvalidCalories;

  /// No description provided for @errorMissingOrInvalidFat.
  ///
  /// In en, this message translates to:
  /// **'Missing or invalid fat.'**
  String get errorMissingOrInvalidFat;

  /// No description provided for @errorMissingOrInvalidProtein.
  ///
  /// In en, this message translates to:
  /// **'Missing or invalid protein.'**
  String get errorMissingOrInvalidProtein;

  /// No description provided for @errorMissingOrInvalidCarbs.
  ///
  /// In en, this message translates to:
  /// **'Missing or invalid carbs.'**
  String get errorMissingOrInvalidCarbs;

  /// No description provided for @errorUpdateCheckTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Update check timed out.'**
  String get errorUpdateCheckTimedOut;

  /// No description provided for @errorUpdateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed.'**
  String get errorUpdateCheckFailed;

  /// No description provided for @errorLatestReleaseTagMissing.
  ///
  /// In en, this message translates to:
  /// **'Latest release tag is missing.'**
  String get errorLatestReleaseTagMissing;

  /// No description provided for @errorApkDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'APK download failed.'**
  String get errorApkDownloadFailed;

  /// No description provided for @errorCouldNotOpenInstaller.
  ///
  /// In en, this message translates to:
  /// **'Could not open installer.'**
  String get errorCouldNotOpenInstaller;

  /// No description provided for @errorInvalidBackupFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file format.'**
  String get errorInvalidBackupFormat;

  /// No description provided for @errorUnsupportedBackupFormatVersion.
  ///
  /// In en, this message translates to:
  /// **'Unsupported backup file version.'**
  String get errorUnsupportedBackupFormatVersion;

  /// No description provided for @errorInvalidSettingsPayload.
  ///
  /// In en, this message translates to:
  /// **'Invalid settings data in backup.'**
  String get errorInvalidSettingsPayload;

  /// No description provided for @errorInvalidRowPayload.
  ///
  /// In en, this message translates to:
  /// **'Invalid row data in backup.'**
  String get errorInvalidRowPayload;

  /// No description provided for @errorInvalidRowPayloadItem.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup row item.'**
  String get errorInvalidRowPayloadItem;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hu':
      return AppLocalizationsHu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
