# Project TODO

Items from the project-wide code review, ordered by priority. Handle and
verify each item independently.

## P1 - Data Integrity

- [x] Correct automatic food-merge conversion factors.
  - Verify the factor direction for same-unit and cross-unit merges.
  - Ensure merging food definitions preserves the represented quantity of
    every historical entry.
  - Add tests for `100 g` into `1 g`, the inverse direction, and compatible
    volume/unit conversions.
  - Relevant code:
    [merge_foods_screen.dart](lib/screens/merge_foods_screen.dart#L94),
    [food_library_service.dart](lib/services/food_library_service.dart#L317),
    [food_library_service_test.dart](test/services/food_library_service_test.dart)
  - Done when merging cannot silently scale historical food quantities or
    nutrition totals incorrectly.

- [x] Make metabolic profile date editing collision-safe.
  - Use the existing date keys to reject or explicitly resolve occupied target
    dates.
  - Track the immutable profile ID separately from the edited date.
  - Ensure Delete always removes the profile originally opened for editing.
  - Add tests for changing to an unused date, changing to an occupied date,
    and deleting after changing the date field.
  - Relevant code:
    [metabolic_profile_screen.dart](lib/screens/metabolic_profile_screen.dart#L139),
    [metabolic_profile_history_service.dart](lib/services/metabolic_profile_history_service.dart#L57),
    [metabolic_profile_history_service_test.dart](test/services/metabolic_profile_history_service_test.dart)
  - Done when editing one profile can neither overwrite nor delete another
    profile unintentionally.

- [x] Enforce relational integrity during data import.
  - Validate that every imported `entry_item` references an entry and food
    included in the same backup payload.
  - Enable SQLite foreign-key enforcement for every database connection.
  - Make the import fail clearly and atomically when relationships are invalid.
  - Add tests for missing entry IDs, missing food IDs, and a valid complete
    import.
  - Relevant code:
    [data_transfer_service.dart](lib/services/data_transfer_service.dart#L157),
    [database_service.dart](lib/services/database_service.dart#L11),
    [data_transfer_service_test.dart](test/services/data_transfer_service_test.dart)
  - Done when an import cannot report success while creating records that are
    hidden by normal joined queries.

## P2 - Behavior And Reliability

- [x] Align daily-summary prompts with the selected nutrition objective.
  - Remove the contradiction between maintenance targets and the active macro
    preset.
  - Treat weight loss as any intake below maintenance; treat all other current
    presets as maintenance-oriented.
  - Compare macro calorie-share percentages with the selected preset instead
    of maintenance-based gram totals.
  - Add prompt/service tests for each objective.
  - Relevant code:
    [day_summary_snapshot_builder.dart](lib/services/day_summary_snapshot_builder.dart),
    [openai_service.dart](lib/services/openai_service.dart#L129),
    [openai_service.dart](lib/services/openai_service.dart#L283)
  - Done when generated coaching evaluates intake against the user's actual
    objective rather than treating maintenance as the objective in all cases.

- [x] Make multi-item copy and delete atomic.
  - Execute each bulk operation in one database transaction.
  - Roll back the entire operation if any selected item fails.
  - Prevent retries from duplicating a partially completed copy.
  - Add tests for success and an injected mid-operation failure.
  - Relevant code:
    [home_screen.dart](lib/screens/home_screen.dart#L244),
    [entries_repository.dart](lib/services/entries_repository.dart),
    [entries_repository_test.dart](test/services/entries_repository_test.dart)
  - Done when a bulk action either applies to every selected item or changes
    nothing.

- [x] Make async food screens safe during navigation.
  - Prevent or safely handle navigation while requests and saves are active.
  - Guard every post-`await` UI update with the appropriate mounted check.
  - Cover success and failure paths in add-food, food-definition, and
    food-item-detail screens.
  - Relevant code:
    [add_new_food_screen.dart](lib/screens/add_new_food_screen.dart#L145),
    [food_definition_screen.dart](lib/screens/food_definition_screen.dart#L153),
    [food_item_detail_screen.dart](lib/screens/food_item_detail_screen.dart),
    [async_food_screens_test.dart](test/screens/async_food_screens_test.dart)
  - Done when leaving a screen during an operation cannot trigger
    `setState()` after disposal or an invalid navigation action.

- [ ] Make home-screen date jumps calendar-based and DST-safe.
  - Replace elapsed-duration day calculations with local calendar-day
    calculations.
  - Test forward and backward jumps across both DST transitions in
    `Europe/Budapest`.
  - Relevant code:
    [home_screen.dart](lib/screens/home_screen.dart#L424)
  - Done when every selected calendar date maps to the correct page regardless
    of whether the interval contains a 23-hour or 25-hour day.

- [ ] Preserve pending debounced settings changes.
  - Flush pending changes before leaving Settings.
  - Cancel or flush pending saves before an import replaces settings.
  - Add tests for immediate navigation after editing and importing during the
    debounce window.
  - Relevant code:
    [settings_screen.dart](lib/screens/settings_screen.dart#L73),
    [settings_screen.dart](lib/screens/settings_screen.dart#L107)
  - Done when a confirmed settings edit is never silently discarded or applied
    after an import unexpectedly.

- [ ] Filter OpenAI models to compatible text models.
  - Do not offer every ID returned by the models endpoint.
  - Validate a selected model before persisting it.
  - Provide a clear fallback when a saved model is no longer available.
  - Relevant code:
    [openai_service.dart](lib/services/openai_service.dart#L177),
    [settings_screen.dart](lib/screens/settings_screen.dart#L523)
  - Done when users cannot select a known-incompatible model for Responses API
    text estimation.

- [ ] Stop sending the initial food-estimation input twice.
  - Ensure the initial text appears exactly once in the constructed request.
  - Preserve subsequent conversation history without duplication.
  - Add a request-construction test for the initial and follow-up turns.
  - Relevant code:
    [add_new_food_screen.dart](lib/screens/add_new_food_screen.dart#L298),
    [openai_service.dart](lib/services/openai_service.dart#L408)
  - Done when captured request payloads contain one copy of each user turn.

- [ ] Make releases reproducible and add an automated regression gate.
  - Track `pubspec.lock` for this application.
  - Pin the Flutter version used by CI instead of following latest stable.
  - Add automated tests for repositories, migrations, date calculations, and
    the highest-risk workflows listed in this file.
  - Validate that the release tag and `pubspec.yaml` version match.
  - Relevant code:
    [.gitignore](.gitignore#L8),
    [android-release.yml](.github/workflows/android-release.yml#L20)
  - Done when the same revision resolves the same dependencies and CI blocks
    releases on test failures or version/tag mismatches.

## P3 - User Experience And Release Safety

- [ ] Keep an existing day summary visible after refresh failure.
  - Do not permanently clear the displayed summary before a replacement has
    succeeded.
  - Restore or retain the persisted summary when re-summarization fails.
  - Relevant code:
    [day_summary_screen.dart](lib/screens/day_summary_screen.dart#L133)
  - Done when a failed refresh shows an error without removing the last valid
    summary from the current screen.

- [ ] Prevent release builds from silently using debug signing.
  - Fail local release builds clearly when release signing configuration is
    absent, or require an explicit opt-in for a debug-signed artifact.
  - Keep CI signing behavior unchanged and secret-safe.
  - Relevant code:
    [build.gradle.kts](android/app/build.gradle.kts#L59)
  - Done when an artifact described as a release cannot be mistaken for a
    properly release-signed build.

## Product Decisions

- [ ] Decide whether editing a food definition should rewrite history.
  - Current behavior recalculates all historical entries that reference the
    edited definition.
  - If history should be immutable, store or retain the nutrition snapshot used
    when each entry was created.
  - Relevant code:
    [entries_repository.dart](lib/services/entries_repository.dart#L184)
  - Done when the intended historical-data policy is documented and enforced
    consistently.

- [ ] Decide how completed weeks with missing logged days affect deficit.
  - Current behavior fills missing past days using the average of logged days.
  - Choose between estimation, treating missing days as unknown, or requiring
    sufficient data before reporting a weekly deficit.
  - Relevant code:
    [weekly_summary_screen.dart](lib/screens/weekly_summary_screen.dart#L142)
  - Done when the intended calculation is documented, visible to users where
    necessary, and covered by tests.
