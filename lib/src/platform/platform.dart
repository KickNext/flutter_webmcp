import '../webmcp_registration_attempt.dart';
import '../webmcp_support.dart';
import '../webmcp_tool.dart';
import '../webmcp_lifecycle_event.dart';

/// Internal adapter implemented by browser and non-browser runtimes.
abstract interface class WebMcpPlatform {
  /// Current WebMCP support state.
  WebMcpSupport get support;

  /// Whether both lifecycle event handlers are exposed by ModelContext.
  bool get isLifecycleEventsSupported;

  /// Browser lifecycle notifications; listeners own their subscriptions.
  Stream<WebMcpLifecycleEvent> get lifecycleEvents;

  /// Starts registering [tool] for the requested origins.
  WebMcpRegistrationAttempt startToolRegistration(
    WebMcpTool tool, {
    required List<String> exposedTo,
  });
}
