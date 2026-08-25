import '../webmcp_registration.dart';
import '../webmcp_support.dart';
import '../webmcp_tool.dart';
import 'platform.dart';

/// Creates the non-browser platform adapter.
WebMcpPlatform createWebMcpPlatform() => const _UnsupportedWebMcpPlatform();

final class _UnsupportedWebMcpPlatform implements WebMcpPlatform {
  const _UnsupportedWebMcpPlatform();

  @override
  WebMcpSupport get support => const WebMcpSupport(
        WebMcpSupportStatus.unsupportedPlatform,
        'WebMCP is only available in a supported web browser.',
      );

  @override
  Future<WebMcpRegistration> registerTool(
    WebMcpTool tool, {
    List<String> exposedTo = const [],
  }) {
    throw UnsupportedError(
      'WebMCP is only available in a supported web browser.',
    );
  }
}
