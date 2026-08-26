## 0.2.1

- Aligned the browser bindings and compatibility tests with the WebMCP Draft
  Community Group Report dated 26 August 2026.
- Expanded browser regression coverage for the current tool definition,
  annotations, registration options, and execution cancellation shape.
- Tolerate experimental browser builds where `registerTool` returns
  synchronously instead of returning the draft's `Promise<void>`.

## 0.2.0

- Added `WebMcpToolScope` for automatic Flutter lifecycle management.
- Added typed inputs with `WebMcpTypedTool<T>`.
- Added `WebMcpResult` helpers for text, structured, raw, and error results.
- Added structured `WebMcpToolException` handling without opaque Dart promise
  failures.
- Added detailed support diagnostics through `WebMcp.support`.
- Added tool-call logging with status, duration, result, and local errors.
- Made execution cancellation data tolerant of browser implementations that do
  not provide an `AbortSignal`.
- Added VM, browser, and Flutter widget regression tests.
- Added strict public API documentation, security guidance, package validation,
  and continuous integration checks for JavaScript and WebAssembly builds.

## 0.1.0

- Initial typed imperative WebMCP API.
- Tool registration and abort-based unregistration.
- Feature detection, JSON Schema input, annotations, and exposed origins.
- Dart VM fallback and tests.
