/// Outcome of a WebMCP tool invocation.
enum WebMcpToolCallStatus {
  /// The tool returned a JSON-compatible result.
  succeeded,

  /// The tool handler, input decoder, or result conversion failed.
  failed,
}

/// Diagnostic information emitted after a tool invocation completes.
final class WebMcpToolCallEvent {
  /// Creates a completed tool-call event.
  const WebMcpToolCallEvent({
    required this.toolName,
    required this.input,
    required this.status,
    required this.duration,
    this.result,
    this.error,
    this.stackTrace,
  });

  /// Name of the invoked tool.
  final String toolName;

  /// JSON input received from the browser agent.
  final Map<String, Object?> input;

  /// Whether execution succeeded or failed.
  final WebMcpToolCallStatus status;

  /// Wall-clock time spent decoding and executing the call.
  final Duration duration;

  /// JSON-compatible successful result, when available.
  final Object? result;

  /// Local error object for failed calls. It is never sent to the agent.
  final Object? error;

  /// Local stack trace for failed calls. It is never sent to the agent.
  final StackTrace? stackTrace;
}

/// Receives diagnostic information after a tool call completes.
typedef WebMcpLogger = void Function(WebMcpToolCallEvent event);

/// Internal process-wide logger shared with the browser adapter.
WebMcpLogger? webMcpLogger;

/// Delivers [event] without allowing logger failures to escape.
void emitWebMcpLog(WebMcpToolCallEvent event) {
  try {
    webMcpLogger?.call(event);
  } catch (_) {
    // Diagnostics must never break a tool call.
  }
}
