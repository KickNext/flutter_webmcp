import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../webmcp.dart';

/// Starts a registration that can be cancelled immediately.
typedef WebMcpToolRegistrationStarter = WebMcpRegistrationAttempt Function(
  WebMcpTool tool, {
  required List<String> exposedTo,
});

/// Registers [tools] while [child] is mounted.
class WebMcpToolScope extends StatefulWidget {
  /// Creates a lifecycle scope for [tools].
  const WebMcpToolScope({
    super.key,
    required this.tools,
    required this.child,
    this.enabled = true,
    this.exposedTo = const [],
    this.onError,
    this.registrationStarter,
    this.supportCheck,
  });

  /// Tool definitions to keep registered while this widget is mounted.
  final List<WebMcpTool> tools;

  /// Widget below this lifecycle scope.
  final Widget child;

  /// Whether registrations should currently be active.
  final bool enabled;

  /// Secure origins allowed to discover these tools in the document tree.
  final List<String> exposedTo;

  /// Receives lifecycle registration errors.
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Overrides registration for custom adapters and tests.
  final WebMcpToolRegistrationStarter? registrationStarter;

  /// Overrides feature detection for custom adapters and tests.
  final bool Function()? supportCheck;

  @override
  State<WebMcpToolScope> createState() => _WebMcpToolScopeState();
}

class _WebMcpToolScopeState extends State<WebMcpToolScope> {
  final Map<String, _ToolSlot> _slots = {};
  bool _reconcileScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleReconcile();
  }

  @override
  void didUpdateWidget(WebMcpToolScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.enabled != widget.enabled ||
        oldWidget.registrationStarter != widget.registrationStarter ||
        oldWidget.supportCheck != widget.supportCheck ||
        !listEquals(oldWidget.tools, widget.tools) ||
        !listEquals(oldWidget.exposedTo, widget.exposedTo);
    if (changed) _scheduleReconcile();
  }

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (mounted) _reconcile();
    });
  }

  void _reconcile() {
    final supported =
        widget.enabled && (widget.supportCheck?.call() ?? WebMcp.isSupported);
    final desired = <String, _ToolConfiguration>{};
    if (widget.enabled && supported) {
      final starter = widget.registrationStarter ?? _defaultStarter;
      for (final tool in widget.tools) {
        if (desired.containsKey(tool.name)) {
          _reportError(
            ArgumentError.value(
                tool.name, 'tools', 'Tool names must be unique.'),
            StackTrace.current,
          );
          continue;
        }
        desired[tool.name] = _ToolConfiguration(
          tool,
          List<String>.of(widget.exposedTo),
          starter,
        );
      }
    }

    for (final entry in _slots.entries.toList()) {
      final next = desired[entry.key];
      if (next == null || !entry.value.matches(next)) {
        _slots.remove(entry.key)?.cancel(_reportError);
      }
    }

    for (final entry in desired.entries) {
      if (_slots.containsKey(entry.key)) continue;
      final slot = _ToolSlot(entry.value);
      _slots[entry.key] = slot;
      slot.start(_reportError);
    }
  }

  void _reportError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'flutter_webmcp',
          context: ErrorDescription(
            'while cancelling WebMCP tools after scope disposal',
          ),
        ),
      );
      return;
    }
    final onError = widget.onError;
    if (onError != null) {
      onError(error, stackTrace);
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'flutter_webmcp',
        context: ErrorDescription('while synchronizing WebMCP tools'),
      ),
    );
  }

  void _reportErrorAfterDispose(Object error, StackTrace stackTrace) {
    final onError = widget.onError;
    scheduleMicrotask(() {
      if (onError != null) {
        onError(error, stackTrace);
        return;
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'flutter_webmcp',
          context: ErrorDescription('while disposing WebMCP tools'),
        ),
      );
    });
  }

  @override
  void dispose() {
    for (final slot in _slots.values) {
      slot.cancel(_reportErrorAfterDispose);
    }
    _slots.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final class _ToolConfiguration {
  const _ToolConfiguration(this.tool, this.exposedTo, this.starter);

  final WebMcpTool tool;
  final List<String> exposedTo;
  final WebMcpToolRegistrationStarter starter;
}

final class _ToolSlot {
  _ToolSlot(this.configuration);

  final _ToolConfiguration configuration;
  WebMcpRegistrationAttempt? _attempt;

  bool matches(_ToolConfiguration other) =>
      identical(configuration.tool, other.tool) &&
      configuration.starter == other.starter &&
      listEquals(configuration.exposedTo, other.exposedTo);

  void start(void Function(Object, StackTrace) reportError) {
    late final WebMcpRegistrationAttempt attempt;
    try {
      attempt = configuration.starter(
        configuration.tool,
        exposedTo: configuration.exposedTo,
      );
    } catch (error, stackTrace) {
      reportError(error, stackTrace);
      return;
    }

    _attempt = attempt;
    unawaited(
      attempt.ready.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_attempt, attempt) && !attempt.isCancelled) {
            reportError(error, stackTrace);
          }
        },
      ),
    );
  }

  void cancel(void Function(Object, StackTrace) reportError) {
    final attempt = _attempt;
    _attempt = null;
    if (attempt == null) return;
    try {
      unawaited(
        attempt.cancel().then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            reportError(error, stackTrace);
          },
        ),
      );
    } catch (error, stackTrace) {
      reportError(error, stackTrace);
    }
  }
}

WebMcpRegistrationAttempt _defaultStarter(
  WebMcpTool tool, {
  required List<String> exposedTo,
}) =>
    WebMcp.startToolRegistration(tool, exposedTo: exposedTo);
