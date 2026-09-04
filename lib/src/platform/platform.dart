import '../webmcp_registration_attempt.dart';
import '../webmcp_support.dart';
import '../webmcp_tool.dart';

/// Internal adapter implemented by browser and non-browser runtimes.
abstract interface class WebMcpPlatform {
  /// Current WebMCP support state.
  WebMcpSupport get support;

  /// Starts registering [tool] for the requested origins.
  WebMcpRegistrationAttempt startToolRegistration(
    WebMcpTool tool, {
    required List<String> exposedTo,
  });
}
