/// Browser notifications about tools owned by the current document.
enum WebMcpLifecycleEventType {
  /// A tool invocation has started.
  activated,

  /// The caller has cancelled a tool invocation.
  cancelled,
}

/// A notification from `document.modelContext`.
///
/// Events identify a tool, not an individual invocation. For concurrent calls
/// of the same tool, use each handler's execution context for cancellation.
final class WebMcpLifecycleEvent {
  /// Creates a notification for [toolName].
  const WebMcpLifecycleEvent({required this.type, required this.toolName});

  /// The kind of browser notification.
  final WebMcpLifecycleEventType type;

  /// Name of the tool owned by this document.
  final String toolName;
}
