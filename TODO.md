# Testing TODO

All automated tests must be deterministic and fully offline. OpenAI and GitHub
requests must use mocked HTTP clients with synthetic responses and dummy
credentials. Unit and widget tests must not depend on live URLs, API keys,
platform dialogs, real delays, or external services.

## P1 - Testability And External Services

- [ ] Introduce the remaining testability seams without changing production
  behavior.
  - Inject an HTTP client, endpoint, and timeout into `UpdateService`, while
    retaining the current production defaults.
  - Inject `UpdateService` into `UpdateCoordinator`, while preserving singleton
    access for the application.
  - Add optional repository, service, and clock dependencies to screens where
    singleton access or `DateTime.now()` prevents deterministic tests.
  - Prefer small constructor dependencies or operation callbacks over adding a
    dependency-injection framework.
  - Add reusable localized-app, navigation, database, and HTTP helpers under
    `test/support/`.
  - Relevant code:
    [update_service.dart](lib/services/update_service.dart),
    [update_coordinator.dart](lib/services/update_coordinator.dart),
    [home_screen.dart](lib/screens/home_screen.dart),
    [weekly_summary_screen.dart](lib/screens/weekly_summary_screen.dart)
  - Done when every high-risk workflow can be exercised without real platform
    services, network access, or wall-clock timing.

- [ ] Add comprehensive offline OpenAI service tests.
  - Use `MockClient` and a dummy API key; never call the live OpenAI API.
  - Cover estimate and day-summary request bodies, headers, schemas, model,
    reasoning effort, output-token limits, localization, and history.
  - Cover valid estimates and summaries, including empty `issues` and
    `suggestions` arrays.
  - Cover invalid outer JSON, invalid content JSON, missing content, missing or
    invalid food fields, empty items, and AI-provided error messages.
  - Cover response-content extraction for every supported OpenAI response
    shape.
  - Cover non-retriable 4xx errors, retriable 429 and 5xx errors, retry limits,
    retry reminder content, and timeouts.
  - Verify `AiParseException` retains the most useful raw response.
  - Cover model fetching, sorting, deduplication, empty responses, and the
    policy of not explicitly whitelisting model IDs.
  - Cover connection-test success, HTTP failure, and timeout.
  - Store representative synthetic responses under `test/fixtures/openai/`.
  - Relevant code:
    [openai_service.dart](lib/services/openai_service.dart),
    [openai_request_history_test.dart](test/services/openai_request_history_test.dart)
  - Done when request construction, parsing, retries, and errors are protected
    without an API key or internet connection.

- [ ] Add comprehensive offline update-service tests.
  - Use an injected mock HTTP client; never call the live GitHub API.
  - Cover newer, equal, and older versions, optional `v` prefixes, differing
    component lengths, and the intended handling of version suffixes.
  - Cover selecting an APK from multiple assets and releases without an APK.
  - Cover missing tags, malformed JSON, malformed assets, HTTP failures, and
    timeouts.
  - Cover coordinator caching, forced refresh, installed-version changes,
    concurrent request deduplication, and clearing failed in-flight requests.
  - Store representative synthetic responses under `test/fixtures/github/`.
  - Relevant code:
    [update_service.dart](lib/services/update_service.dart),
    [update_coordinator.dart](lib/services/update_coordinator.dart)
  - Done when update detection and caching are fully verified offline.

## P2 - Domain And Persistence

- [ ] Add unit tests for currently uncovered domain calculations and models.
  - Cover maintenance and daily-deficit calculations across supported profile
    inputs and activity levels.
  - Cover calorie and macro target calculation, custom ratios, and rounding.
  - Cover `FoodItem` quantity, nutrition, and map-conversion behavior.
  - Expand date tests for week starts, leap years, month/year boundaries, and
    DST-adjacent calendar operations.
  - Cover macro preset lookup, ratio identification, and fallback behavior.
  - Cover day-summary source hashing, canonical JSON, storage, and replacement.
  - Expand weekly-deficit tests for negative deficits, average rounding,
    missing targets, and completed-week boundaries.
  - Relevant code:
    [calorie_deficit_service.dart](lib/services/calorie_deficit_service.dart),
    [nutrition_target_service.dart](lib/services/nutrition_target_service.dart),
    [food_item.dart](lib/models/food_item.dart),
    [app_date_utils.dart](lib/utils/app_date_utils.dart),
    [macro_ratio_preset_catalog.dart](lib/services/macro_ratio_preset_catalog.dart),
    [day_summary_service.dart](lib/services/day_summary_service.dart),
    [weekly_deficit_calculator.dart](lib/services/weekly_deficit_calculator.dart)
  - Done when all pure business rules have success, boundary, and invalid-input
    coverage.

- [ ] Expand database and repository behavior tests.
  - Cover food creation, update, fetch, search, visibility, usage counts,
    deduplication, and normal merge behavior.
  - Cover single-item add, multiplier update, delete, copy, entry reuse,
    ordering, and date-based fetching.
  - Cover effective metabolic profiles before, on, and after profile dates,
    including ranges that cross multiple profile changes.
  - Cover export/import round trips, invalid field types, invalid macro ratios,
    duplicate records, secure-key inclusion policy, and transaction rollback.
  - Cover day-summary persistence and replacement.
  - Continue using in-memory SQLite and injected failure triggers.
  - Relevant code:
    [food_library_service.dart](lib/services/food_library_service.dart),
    [entries_repository.dart](lib/services/entries_repository.dart),
    [metabolic_profile_history_service.dart](lib/services/metabolic_profile_history_service.dart),
    [data_transfer_service.dart](lib/services/data_transfer_service.dart),
    [day_summary_service.dart](lib/services/day_summary_service.dart)
  - Done when normal CRUD behavior and failure atomicity are both protected.

## P3 - Core Widget Workflows

- [ ] Add comprehensive HomeScreen widget tests.
  - Cover loading, error, empty, populated, and missing-target states.
  - Cover date swiping, calendar jumps, current/future-day restrictions,
    selection clearing, and back behavior.
  - Cover long-press selection, tap toggling, selection count, and exiting when
    the final item is deselected.
  - Cover bulk copy and delete enablement, confirmation, busy state, success,
    failure, reloading, and navigation to today.
  - Cover navigation to food details, add food, metric details, weekly summary,
    and daily summary.
  - Exercise phone and Linux-sized viewports.
  - Relevant code:
    [home_screen.dart](lib/screens/home_screen.dart)
  - Done when the application's primary daily workflow is directly protected
    by widget tests.

- [ ] Add widget coverage for the remaining core screens.
  - Weekly summary: Monday-Sunday ranges, completed/current weeks, estimated
    markers, zero-calorie logged days, paging, refresh, loading, and errors.
  - Metabolic profiles: add, edit, delete, validation, date collisions, presets,
    and custom ratios.
  - Foods and add-entry screens: search, selection, visibility, editing,
    returned results, and refresh behavior.
  - Merge foods: source selection, automatic/manual conversion factors,
    confirmation, success, and failure.
  - Settings and About: offline model loading, connection checks, update states,
    persistence errors, and navigation.
  - Shared controls: enabled, disabled, loading, validation, interaction, and
    narrow-layout behavior.
  - Relevant code:
    [weekly_summary_screen.dart](lib/screens/weekly_summary_screen.dart),
    [metabolic_profile_screen.dart](lib/screens/metabolic_profile_screen.dart),
    [foods_screen.dart](lib/screens/foods_screen.dart),
    [add_entry_screen.dart](lib/screens/add_entry_screen.dart),
    [merge_foods_screen.dart](lib/screens/merge_foods_screen.dart),
    [settings_screen.dart](lib/screens/settings_screen.dart),
    [about_screen.dart](lib/screens/about_screen.dart)
  - Done when each user-facing workflow has happy-path, failure, and boundary
    widget coverage at relevant viewport sizes.

## P4 - Integration And Enforcement

- [ ] Add a small offline application integration suite.
  - Cover launching with an empty database.
  - Cover creating a food, logging it, editing it, and verifying live history.
  - Cover copying multiple foods to today.
  - Cover opening weekly summary and verifying the resulting totals.
  - Cover an export/import round trip through injected file operations.
  - Keep these tests separate from unit and widget tests and free of external
    network or platform-service dependencies.
  - Done when the most important user journeys are verified across screen,
    service, and database boundaries.

- [ ] Enforce the testing policy in CI.
  - Run `flutter test --coverage` for pull requests, pushes to `main`, and
    release builds.
  - Exclude generated localization files from application-logic coverage.
  - Fail when designated critical production files are absent from coverage.
  - Start with a realistic 65% application-logic line threshold and raise it
    toward 80% after the core screen and service gaps are covered.
  - Require stronger per-file coverage for pure calculation and parsing
    services.
  - Keep CI free of OpenAI/GitHub credentials and ensure tests cannot silently
    make live network requests.
  - Keep the suite fast and deterministic enough for routine local execution.
  - Relevant code:
    [tests.yml](.github/workflows/tests.yml),
    [android-release.yml](.github/workflows/android-release.yml)
  - Done when CI blocks regressions in both behavior and meaningful test
    coverage.
