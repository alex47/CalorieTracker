# AGENTS.md

## Project
- Name: `CalorieTracker`
- Stack: Flutter (Dart), local SQLite (`sqflite` / `sqflite_common_ffi`), OpenAI API integration.
- Primary target: Android (Linux desktop used for local dev/testing too).

## Goals
- Keep the app stable and fast.
- Prioritize mobile-friendly UI.
- Keep behavior consistent across screens (shared widgets when possible).

## Coding Rules
- Reuse existing patterns and widgets before adding new ones.
- Prefer small, targeted changes over large refactors.
- Keep styles centralized (theme/colors/typography) instead of hardcoding.
- Use clear names; avoid dead code and unused helpers.

## UI Rules
- Maintain current dark theme and centralized color/typography setup.
- Avoid wide desktop-first layouts on phone screens.
- Keep action button behavior consistent (enabled/disabled/loading states).

## Data + API Rules
- Preserve DB compatibility and migrations.
- Keep OpenAI parsing strict and JSON-only.
- Surface AI/user-facing errors in clear language.

## Git Workflow
- Make focused commits with clear messages.
- Do not rewrite history unless explicitly requested.
- Do not commit local editor folders/files (e.g. `.vscode/`).
- Tag/version rule:
  - When creating a new tag, increment the patch version by default based on `pubspec.yaml` (unless the user explicitly says otherwise).
  - When creating a new tag, update `pubspec.yaml` `version` to exactly match the new tag version (without the `v` prefix).

## Verification
- At minimum, run static checks before finalizing if available.
- If tools are unavailable in environment, state that clearly.
