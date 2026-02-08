// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Kalória Követő';

  @override
  String get settingsTitle => 'Beállítások';

  @override
  String get aboutTitle => 'Névjegy';

  @override
  String get addButton => 'Hozzáadás';

  @override
  String get cancelButton => 'Mégse';

  @override
  String get acceptButton => 'Elfogadás';

  @override
  String get deleteButton => 'Törlés';

  @override
  String get reestimateButton => 'Újrabecslés';

  @override
  String get caloriesLabel => 'Kalória';

  @override
  String get fatLabel => 'Zsír';

  @override
  String get proteinLabel => 'Fehérje';

  @override
  String get carbsLabel => 'Szénhidrát';

  @override
  String get foodLabel => 'Étel';

  @override
  String get amountLabel => 'Mennyiség';

  @override
  String get notesLabel => 'Megjegyzések';

  @override
  String caloriesKcalValue(Object calories) {
    return '$calories kcal';
  }

  @override
  String gramsValue(Object value) {
    return '$value g';
  }

  @override
  String get failedToLoadDailyTotals =>
      'A napi összesítők betöltése sikertelen.';

  @override
  String get trackedFoods => 'Rögzített ételek';

  @override
  String get failedToLoadEntries => 'A bejegyzések betöltése sikertelen.';

  @override
  String get emptyEntriesHint =>
      'Erre a napra még nincs bejegyzés. Koppints a Hozzáadás gombra.';

  @override
  String get openAiSectionTitle => 'OpenAI';

  @override
  String get languageLabel => 'Nyelv';

  @override
  String get languageNameNative => 'Magyar';

  @override
  String get languageNameEnglish => 'Hungarian';

  @override
  String get openAiApiKeyLabel => 'OpenAI API kulcs';

  @override
  String get testKeyButton => 'Kulcs tesztelése';

  @override
  String get modelLabel => 'Modell';

  @override
  String get reasoningEffortLabel => 'Következtetési szint';

  @override
  String get maxOutputTokensLabel => 'Maximális kimeneti tokenek';

  @override
  String get openAiTimeoutSecondsLabel => 'Időkorlát (másodperc)';

  @override
  String get goalsSectionTitle => 'Célok';

  @override
  String get dailyCalorieGoalLabel => 'Napi kalóriacél (kcal)';

  @override
  String get dailyFatGoalLabel => 'Napi zsírcél (g)';

  @override
  String get dailyProteinGoalLabel => 'Napi fehérjecél (g)';

  @override
  String get dailyCarbsGoalLabel => 'Napi szénhidrátcél (g)';

  @override
  String get dataToolsSectionTitle => 'Adateszközök';

  @override
  String get exportDataButton => 'Adatok exportálása';

  @override
  String get importDataButton => 'Adatok importálása';

  @override
  String get exportComingSoon => 'Az export hamarosan elérhető.';

  @override
  String get importComingSoon => 'Az import hamarosan elérhető.';

  @override
  String couldNotLoadModels(Object error) {
    return 'A modellek dinamikus betöltése nem sikerült. $error';
  }

  @override
  String get enterApiKeyFirst => 'Először adj meg egy API kulcsot.';

  @override
  String get apiKeyTestSucceeded =>
      'Az API kulcs tesztje sikeres. A kulcs mentve.';

  @override
  String apiKeyTestFailed(Object error) {
    return 'Az API kulcs tesztje sikertelen: $error';
  }

  @override
  String get setApiKeyInSettings =>
      'Állítsd be az OpenAI API kulcsot a Beállításokban.';

  @override
  String failedToFetchCalories(Object error) {
    return 'A kalóriák lekérése sikertelen. $error';
  }

  @override
  String get requestCaloriesBeforeSaving =>
      'Mentés előtt kérj kalóriabecslést.';

  @override
  String get addFoodTitle => 'Étel hozzáadása';

  @override
  String get foodAndAmountsLabel => 'Ételek és mennyiségek';

  @override
  String get enterFoodItems => 'Adj meg étel tételeket.';

  @override
  String get estimateCaloriesButton => 'Kalória becslése';

  @override
  String get missingItemInAiResponse => 'Hiányzó tétel az AI válaszában.';

  @override
  String get invalidReestimatedItemInAiResponse =>
      'Érvénytelen újrabecsült tétel az AI válaszában.';

  @override
  String failedToReestimateItem(Object error) {
    return 'A tétel újrabecslése sikertelen. $error';
  }

  @override
  String failedToSaveItem(Object error) {
    return 'A tétel mentése sikertelen. $error';
  }

  @override
  String get deleteItemTitle => 'Tétel törlése';

  @override
  String get deleteItemConfirmMessage =>
      'Biztosan törölni szeretnéd ezt az étel tételt?';

  @override
  String failedToDeleteItem(Object error) {
    return 'A tétel törlése sikertelen. $error';
  }

  @override
  String failedToCopyItem(Object error) {
    return 'A tétel másolása sikertelen. $error';
  }

  @override
  String get foodDetailsTitle => 'Étel részletei';

  @override
  String get copyToTodayButton => 'Másolás mára';

  @override
  String get askFollowupChangesLabel => 'Kérj további módosításokat';

  @override
  String get couldNotOpenGithubLink => 'A GitHub hivatkozás nem nyitható meg.';

  @override
  String updateCheckFailed(Object error) {
    return 'Frissítés ellenőrzése sikertelen: $error';
  }

  @override
  String get noApkAssetFound =>
      'Nem található APK eszköz a legfrissebb kiadásban.';

  @override
  String get couldNotOpenUpdateUrl =>
      'A frissítés letöltési URL nem nyitható meg.';

  @override
  String updateInstallFailed(Object error) {
    return 'A frissítés telepítése sikertelen: $error';
  }

  @override
  String get installerOpenedMessage =>
      'A telepítő megnyílt. Ha kéri, engedélyezd az alkalmazásból történő telepítést.';

  @override
  String get aboutDescription =>
      'A Kalória Követő segít az étkezések naplózásában és a kalóriák becslésében OpenAI segítségével.';

  @override
  String versionLabel(Object version) {
    return 'Verzió: $version';
  }

  @override
  String get checkForUpdatesButton => 'Frissítések keresése';

  @override
  String updateAvailableStatus(Object latestVersion, Object currentVersion) {
    return 'Frissítés elérhető: $latestVersion (jelenlegi: $currentVersion)';
  }

  @override
  String upToDateStatus(Object currentVersion) {
    return 'Naprakész ($currentVersion).';
  }

  @override
  String get installLatestApkButton => 'Legfrissebb APK telepítése';

  @override
  String get downloadingUpdate => 'Frissítés letöltése...';

  @override
  String downloadingUpdateProgress(Object percent) {
    return 'Frissítés letöltése... $percent%';
  }

  @override
  String get githubRepositoryButton => 'GitHub repó';

  @override
  String get errorOpenAiRequestTimedOut => 'Az OpenAI kérés időtúllépett.';

  @override
  String get errorOpenAiRequestFailed => 'Az OpenAI kérés sikertelen.';

  @override
  String get errorNoModelsReturned =>
      'Ehhez az API kulcshoz nem érkezett modell.';

  @override
  String get errorFailedParseAiResponse =>
      'Az AI válasz feldolgozása sikertelen.';

  @override
  String get errorEmptyAiContent => 'Az AI üres választ adott.';

  @override
  String get errorAiNoItemsNoExplanation =>
      'Az AI nem adott tételeket és magyarázatot sem.';

  @override
  String get errorMissingNameOrAmount =>
      'Hiányzik az étel neve vagy mennyisége.';

  @override
  String get errorMissingOrInvalidCalories =>
      'Hiányzó vagy érvénytelen kalória.';

  @override
  String get errorMissingOrInvalidFat => 'Hiányzó vagy érvénytelen zsír.';

  @override
  String get errorMissingOrInvalidProtein =>
      'Hiányzó vagy érvénytelen fehérje.';

  @override
  String get errorMissingOrInvalidCarbs =>
      'Hiányzó vagy érvénytelen szénhidrát.';

  @override
  String get errorUpdateCheckTimedOut =>
      'A frissítés ellenőrzése időtúllépett.';

  @override
  String get errorUpdateCheckFailed => 'A frissítés ellenőrzése sikertelen.';

  @override
  String get errorLatestReleaseTagMissing =>
      'Hiányzik a legfrissebb kiadás címkéje.';

  @override
  String get errorApkDownloadFailed => 'Az APK letöltése sikertelen.';

  @override
  String get errorCouldNotOpenInstaller => 'A telepítő nem nyitható meg.';
}
