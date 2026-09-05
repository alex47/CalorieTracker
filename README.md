# Calorie Tracker

Calorie Tracker is a dark-theme Flutter app for logging food intake, estimating nutrition with the OpenAI API, and tracking calories, macros, and calorie deficit over time.

The app is built primarily for Android, with Linux desktop support used for local development and testing. Food data is stored locally in SQLite, and the OpenAI API key is stored with `flutter_secure_storage`.

## Features

- Daily food logging with swipe navigation and one-shot copy/paste between dates.
- Reusable food library with search, manual food definitions, portion editing, usage counts, and merge tooling.
- AI-assisted food creation through the OpenAI Responses API with strict JSON output.
- Daily and weekly views for calories, macros, and calorie deficit.
- Metabolic profile history with macro goal presets.
- AI-generated daily summaries with highlights, issues, and suggestions.
- English and Hungarian localization.
- JSON data export/import.
- GitHub Releases update checks and APK install flow on Android.

## App Flow

The home screen shows the selected day, daily calorie progress, macro progress, and tracked foods. Dates are paged by swiping, and future days are blocked. Long-press food rows to select multiple items, then copy and paste them once into another day, copy them directly to today, or delete them.

Adding food starts from the saved food library. The Add Food page shows up to five distinct recently added foods above the full library, newest first. Both lists add the food to the selected day with its standard amount. Only successful additions from this page update the recent list; repeating an addition moves that food to the top. Food creation and copy/paste do not update it. Recent history persists across app restarts and is included in JSON backups. New foods can be created manually or estimated with OpenAI from free-form text, then adjusted before saving.

Food definitions are the live source of truth for linked logs. Editing a food updates the name, nutrition, unit, and notes shown for its past and future entries while preserving each entry's logged quantity.

The metabolic profile screen stores dated profile changes. Daily targets are calculated from the effective profile for each day.

The weekly summary shows daily calorie and macro bars plus weekly deficit. A logged current day shows its actual deficit immediately. On Sunday, logging food makes the full weekly deficit available; missing earlier days use the average deficit from logged days. The same estimation applies to completed past weeks. A zero-calorie food entry counts as a logged day and uses its target-based deficit instead of an estimate. The daily summary screen can generate and cache an AI-written nutrition summary for a logged day.

Settings cover language, OpenAI API key, model options, request limits, and data import/export. About shows the app version, repository link, and update actions.

## Local Setup

Prerequisites:

- Flutter SDK with Dart `>=3.3.0 <4.0.0`
- Android SDK/NDK and Java for Android builds
- Linux desktop build dependencies for local Linux runs

Install dependencies:

```bash
flutter pub get
```

Run on Linux:

```bash
flutter run -d linux
```

If Linux file dialogs do not open through the portal:

```bash
GTK_USE_PORTAL=1 flutter run -d linux
```

Run on Android:

```bash
flutter run -d android
```

## Privacy and Backups

Food logs, food definitions, settings, metabolic profiles, and cached summaries are stored locally. OpenAI-powered features send the relevant food text or day snapshot to the OpenAI API.

Exports are JSON files. The app can optionally include the OpenAI API key in an export, but it warns first because that stores the key in plain text.

## Localization

The app supports English and Hungarian. Localization sources live in `lib/l10n/`.

## License

This project is licensed under GPL-3.0. See `LICENSE`.
