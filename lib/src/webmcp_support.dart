/// Why WebMCP is or is not available in the current environment.
enum WebMcpSupportStatus {
  /// The current page can register WebMCP tools.
  supported,

  /// The current Dart runtime is not a web browser.
  unsupportedPlatform,

  /// The page is not running in a secure context.
  insecureContext,

  /// The browser does not expose `document.modelContext`.
  browserApiUnavailable,
}

/// A feature-detection result with a status and readable explanation.
final class WebMcpSupport {
  /// Creates a support result.
  const WebMcpSupport(this.status, this.message);

  /// Machine-readable support state.
  final WebMcpSupportStatus status;

  /// Human-readable explanation of [status].
  final String message;

  /// Whether WebMCP tools can be registered in the current environment.
  bool get isSupported => status == WebMcpSupportStatus.supported;

  @override
  String toString() => 'WebMcpSupport($status, $message)';
}
