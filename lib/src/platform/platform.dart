import '../webmcp_registration.dart';
import '../webmcp_support.dart';
import '../webmcp_tool.dart';

/// Internal adapter implemented by browser and non-browser runtimes.
abstract interface class WebMcpPlatform {
  /// Current WebMCP support state.
  WebMcpSupport get support;

  /// Registers [tool] for the requested origins.
  Future<WebMcpRegistration> registerTool(
    WebMcpTool tool, {
    List<String> exposedTo,
  });
}
