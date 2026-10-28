# Repository Guidelines

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
