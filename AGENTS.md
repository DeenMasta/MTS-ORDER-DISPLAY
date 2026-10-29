x# Repository Guidelines

## Project Structure & Module Organization

`lib/main.dart` is the application entry point and contains the starter screen. Keep new Flutter application code under `lib/`; organize domain features into their own directories when implementation begins. Platform runners live in `android/`, `windows/`, and `web/`. The Android application identifier is `com.mysztechnology.mysztech_order_display`. Widget tests belong in `test/` and mirror their corresponding `lib/` areas where practical.

## Build, Test, and Development Commands

- `flutter pub get` resolves dependencies declared in `pubspec.yaml`.
- `flutter run -d windows` runs the Windows target; choose another detected Flutter device as needed.
- `flutter test` runs all widget tests. To run one test file, use `flutter test test/widget_test.dart`.
- `flutter analyze` applies the project's static analysis configuration.

## Coding Style & Naming Conventions

Use Dart's standard formatting with `dart format .`. Static analysis includes `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`; keep the analyzer clean rather than adding broad exclusions. Use `PascalCase` for types and widgets, `camelCase` for members, and `snake_case.dart` for Dart filenames.

## Testing Guidelines

The project uses Flutter's built-in `flutter_test` package. Add or update tests alongside behavior changes, and run `flutter test` before handing off a change.

## Flutter Architecture

For every Flutter code change, read and follow `.agents/skills/flutter-apply-architecture-best-practices/SKILL.md`.

- Keep presentation/UI, business logic, and data access separate.
- Keep widgets focused on rendering and UI-only interactions.
- Put screen state and user actions in `ChangeNotifier` ViewModels (or an equivalent `Listenable`).
- Put API, database, and platform access in services behind repositories.
- Add a domain/use-case class only when logic is complex or reused across ViewModels.
- Inject dependencies explicitly instead of constructing data services inside widgets.
- Add or update tests for non-trivial ViewModel, repository, and feature behavior.
- Run `dart format .`, `flutter analyze`, and `flutter test` before handoff.

## Ponytail Workflow

For coding, fixing, refactoring, reviewing, and dependency-selection tasks, also follow the installed `ponytail:ponytail` skill at its default `full` level.

- Inspect the affected code, callers, tests, fixtures, configuration, and exports before editing.
- Make the smallest complete change; do not add speculative features, abstractions, or dependencies.
- Preserve validation, error handling, security, accessibility, and data-safety behavior.
- For non-trivial logic, add a focused test or assert-based self-check.
- Before handoff, state what was skipped or not checked and any remaining risk.
