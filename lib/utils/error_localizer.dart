import 'package:calorie_tracker/l10n/app_localizations.dart';

String localizeError(Object error, AppLocalizations l10n) {
  var raw = error.toString().trim();
  if (raw.startsWith('Bad state: ')) {
    raw = raw.substring('Bad state: '.length).trim();
  } else if (raw.startsWith('FormatException: ')) {
    raw = raw.substring('FormatException: '.length).trim();
  }

  if (raw.startsWith('OpenAI request timed out.')) {
    return l10n.errorOpenAiRequestTimedOut;
  }
  // Preserve model-authored content verbatim.
  if (raw.startsWith('The AI says:')) {
    return raw;
  }
  if (raw.startsWith('OpenAI request failed:')) {
    return l10n.errorOpenAiRequestFailed;
  }
  if (raw.startsWith('No models were returned for this API key.')) {
    return l10n.errorNoModelsReturned;
  }
  if (raw.startsWith('Failed to parse AI response after')) {
    return l10n.errorFailedParseAiResponse;
  }
  if (raw.startsWith('Empty content in response.')) {
    return l10n.errorEmptyAiContent;
  }
  if (raw.startsWith('AI returned no items and no explanation.')) {
    return l10n.errorAiNoItemsNoExplanation;
  }
  if (raw.startsWith('Missing name or amount.')) {
    return l10n.errorMissingNameOrAmount;
  }
  if (raw.startsWith('Missing or invalid calories.')) {
    return l10n.errorMissingOrInvalidCalories;
  }
  if (raw.startsWith('Missing or invalid fat.')) {
    return l10n.errorMissingOrInvalidFat;
  }
  if (raw.startsWith('Missing or invalid protein.')) {
    return l10n.errorMissingOrInvalidProtein;
  }
  if (raw.startsWith('Missing or invalid carbs.')) {
    return l10n.errorMissingOrInvalidCarbs;
  }
  if (raw.startsWith('Update check timed out.')) {
    return l10n.errorUpdateCheckTimedOut;
  }
  if (raw.startsWith('Update check failed:')) {
    return l10n.errorUpdateCheckFailed;
  }
  if (raw.startsWith('Latest release tag is missing.')) {
    return l10n.errorLatestReleaseTagMissing;
  }
  if (raw.startsWith('APK download failed:')) {
    return l10n.errorApkDownloadFailed;
  }
  if (raw.startsWith('Could not open installer:')) {
    return l10n.errorCouldNotOpenInstaller;
  }

  return raw;
}
