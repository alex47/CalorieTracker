# CalorieTracker

CalorieTracker is a Flutter app for tracking daily food intake with AI-assisted nutrition estimates.
It stores data locally (SQLite), supports localization (English/Hungarian), and includes Android release/update tooling.

## What the app does

- Tracks food entries by day.
- Uses OpenAI to estimate per-item:
  - calories (kcal)
  - fat (g)
  - protein (g)
  - carbs (g)
  - notes
- Lets you refine/re-estimate parsed items before saving.
- Provides daily and weekly summaries with progress/bar visualizations.
- Supports per-day goal history (goal changes apply from the change date onward).
- Supports import/export of app data.
- Supports in-app update checking against GitHub Releases.

## Main features

- **Home**
  - Swipe between dates (no future dates).
  - Daily total progress + macro progress.
  - Tap metrics to open per-metric daily contribution details.
  - Tap date to open weekly summary.
- **Add food**
  - Multi-line food input.
  - AI estimate + follow-up re-estimation.
  - Structured nutrition breakdown preview.
- **Food details**
  - Edit via AI re-estimation.
  - Delete item.
  - Copy item to today (for older dates).
- **Weekly summary**
  - Per-day bars for calories/macros relative to each day’s configured goal.
  - Swipe weeks, blocked from future weeks.
- **Settings**
  - OpenAI key test and model selection.
  - Reasoning effort, max output tokens, request timeout.
  - Daily goals (calories/macros).
  - Language selection.
  - Data export/import.
- **About**
  - App version.
  - GitHub link.
  - Update status + install latest APK flow (Android).

## Tech stack

- Flutter (Dart)
- SQLite:
  - `sqflite` (mobile)
  - `sqflite_common_ffi` (Linux)
- OpenAI Responses API (`/v1/responses`) with JSON schema output
- `flutter_secure_storage` for sensitive settings (API key)

## Project structure

- `lib/screens/` UI pages
- `lib/widgets/` reusable UI components
- `lib/services/` data, AI, update, settings, import/export services
- `lib/models/` app/domain models and defaults
- `lib/theme/` centralized colors and UI constants
- `lib/l10n/` localization resources

## Local setup

### Prerequisites

- Flutter SDK (matching your project setup)
- Linux desktop build deps (for local Linux dev)
- Android SDK/NDK + Java (for Android builds)

### Install

```bash
flutter pub get
```

### Run (Linux)

```bash
flutter run -d linux
```

If file dialogs do not open via portal on Linux, run with:

```bash
GTK_USE_PORTAL=1 flutter run -d linux
```

### Run static checks

```bash
flutter analyze
```

## OpenAI configuration

Set in **Settings**:

- API key (saved only after successful key test)
- Model
- Reasoning effort (`minimal | low | medium | high`)
- Max output tokens
- Timeout (seconds)
- App language used for localized UI and AI output language instructions

## Data storage and transfer

- Data is stored locally in SQLite.
- Export includes:
  - settings
  - goal history
  - entries
  - entry items
- Import restores those datasets into local DB.

## Android release automation

GitHub Actions workflow: `.github/workflows/android-release.yml`

Triggered by tags (`v*`) and builds signed release APKs.

Required repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

The workflow publishes APK assets to GitHub Releases.

## In-app updates

The app checks GitHub Releases for latest version (`alex47/CalorieTracker`) and compares semantic version parts.
On supported platforms, users can download/install latest APK from the About page flow.

## Current targets

- Primary: Android
- Local dev/testing: Linux desktop

## License

See `LICENSE`.
