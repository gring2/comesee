# Repository Guidelines

## Project Structure & Module Organization
- `lib/`: Main Flutter app code; keep feature modules in subfolders (e.g., `lib/features/auth`, `lib/widgets`).
- `test/`: Unit and widget tests; mirror `lib/` paths and suffix files with `_test.dart`.
- `assets/`: Add images/fonts here and declare them in `pubspec.yaml`.
- Platform folders (`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`): Keep platform-specific tweaks isolated and prefer Dart-side configuration when possible.
- `docs/`: Project docs; place design notes or ADRs here to avoid cluttering `lib/`.

## Build, Test, and Development Commands
- `flutter pub get`: Install dependencies.
- `flutter analyze`: Static analysis/lints; gate changes on a clean run.
- `flutter test`: Run all unit/widget tests; ensure new features add or update coverage.
- `flutter run -d <device_id>`: Launch the app locally; use `flutter devices` to list targets.
- `dart format lib test`: Format Dart code; run before committing.

## Coding Style & Naming Conventions
- Dart style: 2-space indentation, trailing commas in widget trees for stable formatting, avoid wildcard imports.
- Naming: Classes/widgets use `PascalCase`; methods/fields `camelCase`; files and directories `snake_case.dart`.
- Widgets: Prefer small, composable widgets; push business logic into services or view models rather than UI code.
- Imports: Use package imports (`package:my_app/...`) instead of relative paths once files move across modules.

## Testing Guidelines
- Framework: Flutter test runner (`flutter test`) with `flutter_test`.
- Structure: Place tests alongside mirrored production paths, e.g., `lib/features/home/home_page.dart` -> `test/features/home/home_page_test.dart`.
- Naming: Test files end with `_test.dart`; group tests with `group()` and describe behavior, not implementation.
- Expectations: Add widget tests for UI states and unit tests for logic-heavy helpers; include regression tests when fixing bugs.

## Commit & Pull Request Guidelines
- Commits: Prefer Conventional Commit prefixes (`feat:`, `fix:`, `chore:`, `docs:`, `test:`) and keep messages imperative and scoped (e.g., `feat: add profile avatar picker`).
- Pull Requests: Provide a concise summary, linked issue/trello ticket, and screenshots or screen recordings for UI changes (`flutter run --profile` captures acceptable). Note any config steps (e.g., required `--dart-define` keys) and testing performed (`flutter analyze`, `flutter test`).

## Security & Configuration Tips
- Secrets: Never commit API keys or credentials; inject via `--dart-define` or platform-specific secure stores. Add sample keys in a `.env.sample` if needed.
- Review: Check differential for platform config changes (Android manifests, iOS Info.plist) and request a second review for permission-related updates.
