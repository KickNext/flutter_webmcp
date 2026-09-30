import '../webmcp_registration_attempt.dart';
import '../webmcp_support.dart';
import '../webmcp_tool.dart';
import '../webmcp_lifecycle_event.dart';
import 'platform.dart';

/// Creates the non-browser platform adapter.
WebMcpPlatform createWebMcpPlatform() => const _UnsupportedWebMcpPlatform();

final class _UnsupportedWebMcpPlatform implements WebMcpPlatform {
  const _UnsupportedWebMcpPlatform();

  @override
  bool get isLifecycleEventsSupported => false;

  @override
  Stream<WebMcpLifecycleEvent> get lifecycleEvents => const Stream.empty();

  @override
  WebMcpSupport get support => const WebMcpSupport(
        WebMcpSupportStatus.unsupportedPlatform,
        'WebMCP is only available in a supported web browser.',
      );

  @override
  WebMcpRegistrationAttempt startToolRegistration(
    WebMcpTool tool, {
    required List<String> exposedTo,
  }) {
    throw UnsupportedError(
      'WebMCP is only available in a supported web browser.',
    );
  }
}
