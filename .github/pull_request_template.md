## Summary

Describe the user-visible change and why it is needed.

## Compatibility

- WebMCP specification or browser behavior affected:
- Breaking API change: yes / no
- JavaScript and WebAssembly impact:

## Verification

- [ ] `dart format --output=none --set-exit-if-changed lib test example/lib`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `dart test -p chrome test/webmcp_browser_test.dart`
- [ ] Documentation and `CHANGELOG.md` updated when needed
- [ ] No credentials, generated builds, or private data included
