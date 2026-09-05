# AGENTS.md

## Project

- Name: `CalorieTracker`
- Stack: Flutter/Dart, local SQLite (`sqflite` and
  `sqflite_common_ffi`), and the OpenAI Responses API.
- Primary target: Android. Linux desktop is also supported for local
  development and integration testing.
- The app is local-first. Food data, settings, profiles, and cached summaries
  live on the device. API keys are stored with `flutter_secure_storage`.

## Start Here

- Read `README.md` for current product behavior and supported workflows.
- Check `TODO.md` for outstanding work only. Completed work should not remain
  there.
- Inspect the relevant implementation and tests before changing behavior.
- Treat this file as the source of durable, project-wide engineering rules.
  Update it when those rules or the project structure change; keep detailed
  feature documentation in `README.md`.

## Architecture

- `lib/main.dart`: app bootstrap, global theme, localization, and top-level
  routes.
- `lib/models/`: domain and settings data structures.
- `lib/screens/`: screen state, presentation, and navigation.
- `lib/services/`: database access, business rules, API integration, updates,
  import/export, and calculations.
- `lib/widgets/`: shared UI controls and reusable presentation components.
- `lib/theme/`: centralized colors, dimensions, and typography constants.
- `lib/utils/app_date_utils.dart`: calendar-safe day and week arithmetic.
- `test/`: unit and widget tests. `integration_test/` contains offline
  application journeys backed by SQLite.
- `.github/workflows/`: CI tests and Android release automation.

Production services commonly expose a normal method using the app database and
an `...InDatabase` variant for isolated tests. Preserve that pattern when it
keeps database behavior directly testable. Screens use optional injected
callbacks where needed for deterministic widget tests.

## Coding Rules

- Reuse existing patterns, services, and widgets before adding abstractions.
- Prefer small, targeted changes over broad refactors.
- Keep ownership boundaries intact: UI state belongs in screens, reusable
  domain behavior belongs in services, and shared presentation belongs in
  widgets.
- Keep styles centralized in `AppColors`, `UiConstants`, and the app theme.
- Use clear names and remove dead code or unused helpers introduced by a
  change.
- Do not add dependencies when the existing SDK or project code is sufficient.
- Preserve test seams and injectable clocks/callbacks instead of coupling tests
  to platform state.

## Domain Invariants

- Calendar weeks run Monday through Sunday.
- Use `AppDateUtils` for calendar-day paging, ranges, and week calculations.
  Do not use elapsed-hour differences or `Duration(days: ...)` for calendar
  arithmetic because those fail across daylight-saving transitions.
- Add DST-boundary coverage when changing date or week behavior.
- Food definitions are the live source of truth for linked food logs. Preserve
  each log entry's quantity when changing a definition.
- Adding or copying a food to a day where that food already exists combines its
  quantity into the first existing item for that food instead of creating
  another row.
- Recent-food history is updated only by successful additions from the Add Food
  page, in the same transaction as the log change. Food creation and copying
  must not update this history.
- Weekly deficit behavior and estimation rules are documented in `README.md`.
  Do not change those rules incidentally while changing presentation code.

## UI Rules

- Maintain the current dark theme and mobile-first layout.
- Use the shared controls in `lib/widgets/` instead of direct stock controls
  when an equivalent exists:
  - `AppButton` and `AppIconButton` for buttons.
  - `LabeledInputBox` for text and form fields.
  - `LabeledDropdownBox` for dropdown fields.
  - `LabeledGroupBox` for grouped content.
  - `FoodTableCard` for food and table-style lists.
  - `AppDialog` and `DialogActionRow` for dialogs.
- Keep enabled, disabled, loading, confirmation, and failure states consistent
  with existing screens.
- Keep phone layouts usable; verify compact and desktop viewports for layout
  changes.
- Put dimensions and colors in the shared theme files instead of hardcoding
  them in screens.

## Localization

- Do not hardcode user-facing strings in Dart files.
- Add or update every message in both `lib/l10n/app_en.arb` and
  `lib/l10n/app_hu.arb`.
- Run `flutter gen-l10n` after editing ARB files.
- Generated `app_localizations*.dart` files are tracked and must be committed
  with their ARB sources. Generate them rather than editing them manually.

## Database And Backups

- Preserve installed-database compatibility. Schema changes must update both
  schema creation and incremental migration logic in `DatabaseService`, bump
  `DatabaseService.schemaVersion`, and include migration tests.
- Keep foreign keys enabled and use transactions for multi-row changes that
  must succeed or fail together.
- Maintain referential integrity among foods, entries, entry items, profiles,
  summaries, and imported data.
- Backup import intentionally accepts only the current backup format. Do not
  add compatibility for older backup formats unless explicitly requested.
- Validate an entire import before replacing user data.

## OpenAI And Network Rules

- Keep OpenAI requests on the Responses API and parsing strict and JSON-only.
- Preserve request limits, timeouts, error localization, and cached-summary
  behavior unless the task explicitly changes them.
- Never log, commit, or expose API keys or release credentials.
- Automated tests must remain offline. `test/flutter_test_config.dart` and
  `integration_test/flutter_test_config.dart` reject unmocked HTTP clients.
- Use injected clients and fixtures under `test/fixtures/` for OpenAI and
  GitHub responses. Do not weaken the offline override to make a test pass.

## Verification

- Do **not** run `flutter analyze` in this repository.
- Format-check touched Dart files:

  ```bash
  dart format --output=none --set-exit-if-changed <touched Dart files>
  ```

- Run focused tests while developing, then run the full unit/widget suite:

  ```bash
  flutter test
  ```

- For broad production changes, database changes, or test-policy changes, run
  the coverage policy used by CI:

  ```bash
  flutter test --coverage
  dart run tool/check_coverage.dart
  ```

- Run the offline Linux integration journey when changing database-backed or
  cross-screen workflows:

  ```bash
  xvfb-run --auto-servernum flutter test integration_test/offline_app_test.dart
  ```

- CI installs dependencies with `flutter pub get --enforce-lockfile`. Keep
  `pubspec.lock` synchronized when dependencies change.
- State clearly when a required check cannot be run. Do not claim verification
  that was not performed.

## Git And Releases

- Inspect the working tree before editing, staging, and committing. Preserve
  unrelated user or agent changes.
- Make focused commits with clear messages. Stage only files belonging to the
  current task.
- Do not amend, squash, rebase, reset, rewrite history, or push unless the user
  explicitly requests it.
- Do not add new local editor or agent metadata. Leave existing tracked IDE
  files alone unless their removal is explicitly requested.
- Release tags use `vX.Y.Z`. A tag triggers the Android release workflow in
  `.github/workflows/android-release.yml`.
- When creating a tag, increment the patch version from `pubspec.yaml` by
  default unless the user specifies another version.
- Before tagging, update `pubspec.yaml` so its version exactly matches the tag
  without the `v` prefix, and commit that version change.
- Verify that the tag points to the version commit before pushing it.
