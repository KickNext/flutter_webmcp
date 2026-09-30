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
DART_TEST_CONFIG=test/native_browser_config.yaml dart test -p chrome test/webmcp_native_browser_test.dart
flutter analyze example
(cd example && flutter build web --release)
(cd example && flutter build web --wasm --release)
flutter pub publish --dry-run
```

Chrome browser tests require a Chrome installation. Manual WebMCP testing may
also require `chrome://flags/#enable-webmcp-testing`.

`webmcp_browser_test.dart` verifies the Dart bindings with controlled browser
fixtures. `webmcp_native_browser_test.dart` additionally checks actual browser
activation, cancellation ordering, and iframe ownership when the native API
is present. It explicitly skips on browsers without the lifecycle API; a skip
does not establish native WebMCP conformance.
The separate native browser config enables experimental Chromium features in
the test browser only. In PowerShell, set `$env:DART_TEST_CONFIG` to the config
path for this command, then remove it with `Remove-Item Env:DART_TEST_CONFIG`.
Run binding fixtures without this config, so native read-only
properties do not interfere with their controlled ModelContext fixtures.

## Pull requests

- Explain the user-visible behavior and compatibility impact.
- Update `README.md` and `CHANGELOG.md` when appropriate.
- Do not commit generated `build/`, `.dart_tool/`, `doc/api/`, or root
  `pubspec.lock` files.
