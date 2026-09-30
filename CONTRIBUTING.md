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
dart format --output=none --set-exit-if-changed lib test tool example/lib
flutter analyze
flutter test
dart test -p chrome test/webmcp_browser_test.dart
CHROME_EXECUTABLE=/path/to/canary/chrome dart run tool/check_native_browser.dart
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
is present. This suite fails when the native lifecycle API is absent. Use a
recent Chrome Canary (CI pins Chrome for Testing 157.0.8079.0), setting
`CHROME_EXECUTABLE` to its executable path. Stable Chrome may expose registration
without the newer lifecycle events.
The native runner enables experimental Chromium features in the test browser
only. In PowerShell, set `$env:CHROME_EXECUTABLE` to the executable path for
this command, then remove it with `Remove-Item Env:CHROME_EXECUTABLE`.
Run binding fixtures without this config, so native read-only
properties do not interfere with their controlled ModelContext fixtures.

`check_native_browser.dart` also serves the compiled Dart bindings with actual HTTP
headers and verifies both allowed registration and `NotAllowedError` under
`Permissions-Policy: tools=()`, including inherited denial in same-origin
descendants. It uses isolated temporary Chrome profiles and requires native
WebMCP support. Pass `--serve` to inspect the printed fixture URLs in the in-app
browser or another browser manually.

## Pull requests

- Explain the user-visible behavior and compatibility impact.
- Update `README.md` and `CHANGELOG.md` when appropriate.
- Do not commit generated `build/`, `.dart_tool/`, `doc/api/`, or root
  `pubspec.lock` files.
