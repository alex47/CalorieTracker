import 'package:calorie_tracker/l10n/app_localizations.dart';
import '../services/openai_service.dart';

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
  if (raw.startsWith(OpenAIService.aiSaysErrorPrefix)) {
    final aiMessage = raw.substring(OpenAIService.aiSaysErrorPrefix.length).trim();
    return l10n.aiSaysPrefix(aiMessage);
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
  if (raw.startsWith('Failed to parse AI response.')) {
    return l10n.errorFailedParseAiResponse;
  }
  if (raw.startsWith('Missing summary text.')) {
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
  if (raw.startsWith('Invalid backup format.')) {
    return l10n.errorInvalidBackupFormat;
  }
  if (raw.startsWith('Unsupported backup format version.')) {
    return l10n.errorUnsupportedBackupFormatVersion;
  }
  if (raw.startsWith('Invalid settings payload.')) {
    return l10n.errorInvalidSettingsPayload;
  }
  if (raw.startsWith('Invalid row payload.')) {
    return l10n.errorInvalidRowPayload;
  }
  if (raw.startsWith('Invalid row payload item.')) {
    return l10n.errorInvalidRowPayloadItem;
  }

  return raw;
}
