# Contributing

Thanks for helping improve `flutter_webmcp`.

Participation is governed by the project's
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Before opening a change

1. Discuss large API changes in an issue first. WebMCP is still a draft, so
   compatibility with the current specification matters.
2. Keep the framework-independent API in `lib/webmcp.dart`. Flutter lifecycle
   helpers belong in `lib/flutter_webmcp.dart`.
3. Add regression tests for behavior changes.

## Local checks

Run these commands from the package root:

```sh
dart format --output=none --set-exit-if-changed lib test example/lib
flutter analyze
flutter test
dart test -p chrome test/webmcp_browser_test.dart
flutter analyze example
(cd example && flutter build web --release)
(cd example && flutter build web --wasm --release)
flutter pub publish --dry-run
```

Chrome browser tests require a Chrome installation. Manual WebMCP testing may
also require `chrome://flags/#enable-webmcp-testing`.

## Pull requests

- Explain the user-visible behavior and compatibility impact.
- Update `README.md` and `CHANGELOG.md` when appropriate.
- Do not commit generated `build/`, `.dart_tool/`, `doc/api/`, or root
  `pubspec.lock` files.
