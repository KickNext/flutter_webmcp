/// An error reported while registering or executing a WebMCP tool.
final class WebMcpException implements Exception {
  /// Creates an infrastructure error with an optional local [cause].
  const WebMcpException(this.message, [this.cause]);

  /// A human-readable explanation of the failure.
  final String message;

  /// The original local error, when one is available.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'WebMcpException: $message'
      : 'WebMcpException: $message ($cause)';
}

/// A failure that should be returned to the agent in a structured form.
final class WebMcpToolException implements Exception {
  /// Creates a tool failure safe to return to the calling agent.
  const WebMcpToolException({
    required this.code,
    required this.message,
    this.details,
    this.cause,
  });

  /// A stable, machine-readable identifier such as `task_not_found`.
  final String code;

  /// A short explanation safe to show to the user and the agent.
  final String message;

  /// Optional JSON-serializable context that can help the agent recover.
  final Object? details;

  /// Original local error. It is logged but is not sent to the agent.
  final Object? cause;

  @override
  String toString() => 'WebMcpToolException($code): $message';
}
