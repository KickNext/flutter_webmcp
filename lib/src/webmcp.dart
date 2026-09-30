import 'dart:convert';

import 'platform/platform.dart';
import 'platform/platform_stub.dart'
    if (dart.library.js_interop) 'platform/platform_web.dart';
import 'webmcp_registration.dart';
import 'webmcp_registration_attempt.dart';
import 'webmcp_logging.dart';
import 'webmcp_support.dart';
import 'webmcp_tool.dart';
import 'webmcp_lifecycle_event.dart';

/// Entry point for WebMCP feature detection and tool registration.
abstract final class WebMcp {
  static final WebMcpPlatform _platform = createWebMcpPlatform();

  /// Whether the current browser exposes `document.modelContext`.
  static bool get isSupported => support.isSupported;

  /// Detailed feature-detection result for the current page.
  static WebMcpSupport get support => _platform.support;

  /// Whether the browser exposes both ModelContext lifecycle event handlers.
  ///
  /// Older browsers may support registration without these events.
  static bool get isLifecycleEventsSupported =>
      _platform.isLifecycleEventsSupported;

  /// Activation and cancellation notifications for this document's tools.
  ///
  /// Each access creates a broadcast stream bound to the current ModelContext.
  /// Native listeners attach on the first subscription and detach when the last
  /// subscription is cancelled. Events are not buffered without listeners.
  /// Unsupported runtimes return an empty stream.
  ///
  /// Cancel subscriptions when their owner ends. Events contain no invocation
  /// ID; use [WebMcpExecutionContext.isCancelled] inside individual handlers.
  static Stream<WebMcpLifecycleEvent> get lifecycleEvents =>
      _platform.lifecycleEvents;

  /// Receives completed tool calls for debugging and observability.
  static set logger(WebMcpLogger? value) => webMcpLogger = value;

  /// The callback that currently receives completed tool calls, if any.
  static WebMcpLogger? get logger => webMcpLogger;

  /// Registers [tool] until the returned handle is unregistered.
  static Future<WebMcpRegistration> registerTool(
    WebMcpTool tool, {
    List<String> exposedTo = const [],
  }) {
    return startToolRegistration(tool, exposedTo: exposedTo).ready;
  }

  /// Starts registering [tool] and returns a handle that can cancel it.
  static WebMcpRegistrationAttempt startToolRegistration(
    WebMcpTool tool, {
    List<String> exposedTo = const [],
  }) {
    _validate(tool, exposedTo);
    return _platform.startToolRegistration(tool, exposedTo: exposedTo);
  }

  static void _validate(WebMcpTool tool, List<String> exposedTo) {
    if (!RegExp(r'^[A-Za-z0-9_.-]{1,128}$').hasMatch(tool.name)) {
      throw ArgumentError.value(
        tool.name,
        'tool.name',
        'Use 1-128 ASCII letters, digits, underscores, hyphens, or dots.',
      );
    }
    if (tool.description.trim().isEmpty) {
      throw ArgumentError.value(
        tool.description,
        'tool.description',
        'Description must not be empty.',
      );
    }
    for (final origin in exposedTo) {
      final uri = Uri.tryParse(origin);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw ArgumentError.value(
          origin,
          'exposedTo',
          'Expected an origin URL.',
        );
      }
    }
    try {
      jsonEncode(tool.inputSchema);
    } catch (error) {
      throw ArgumentError.value(
        tool.inputSchema,
        'tool.inputSchema',
        'Schema must contain JSON-serializable values: $error',
      );
    }
  }
}
