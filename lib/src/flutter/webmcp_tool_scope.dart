import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../webmcp.dart';

/// Registers one tool and returns its lifecycle handle.
typedef WebMcpToolRegistrar = Future<WebMcpRegistration> Function(
  WebMcpTool tool, {
  List<String> exposedTo,
});

/// Registers [tools] while [child] is mounted and unregisters them on dispose.
class WebMcpToolScope extends StatefulWidget {
  /// Creates a lifecycle scope for [tools].
  const WebMcpToolScope({
    super.key,
    required this.tools,
    required this.child,
    this.enabled = true,
    this.exposedTo = const [],
    this.onError,
    this.registrar,
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
  final WebMcpToolRegistrar? registrar;

  /// Overrides feature detection for custom adapters and tests.
  final bool Function()? supportCheck;

  @override
  State<WebMcpToolScope> createState() => _WebMcpToolScopeState();
}

class _WebMcpToolScopeState extends State<WebMcpToolScope> {
  List<WebMcpRegistration> _registrations = [];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(WebMcpToolScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.enabled != widget.enabled ||
        oldWidget.registrar != widget.registrar ||
        oldWidget.supportCheck != widget.supportCheck ||
        !listEquals(oldWidget.tools, widget.tools) ||
        !listEquals(oldWidget.exposedTo, widget.exposedTo);
    if (changed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    await _unregisterCurrent();
    if (!mounted || generation != _generation || !widget.enabled) return;

    final supported = widget.supportCheck?.call() ?? WebMcp.isSupported;
    if (!supported) return;

    final registrar = widget.registrar ?? _defaultRegistrar;
    final next = <WebMcpRegistration>[];
    try {
      for (final tool in widget.tools) {
        next.add(
          await registrar(tool, exposedTo: widget.exposedTo),
        );
        if (!mounted || generation != _generation) {
          await _unregister(next);
          return;
        }
      }
      _registrations = next;
    } catch (error, stackTrace) {
      await _unregister(next);
      if (mounted && generation == _generation) {
        _reportError(error, stackTrace);
      }
    }
  }

  Future<void> _unregisterCurrent() async {
    final current = _registrations;
    _registrations = [];
    await _unregister(current);
  }

  Future<void> _unregister(List<WebMcpRegistration> registrations) async {
    for (final registration in registrations.reversed) {
      try {
        await registration.unregister();
      } catch (error, stackTrace) {
        if (mounted) _reportError(error, stackTrace);
      }
    }
  }

  void _reportError(Object error, StackTrace stackTrace) {
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

  @override
  void dispose() {
    _generation++;
    final current = _registrations;
    _registrations = [];
    for (final registration in current.reversed) {
      unawaited(registration.unregister());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<WebMcpRegistration> _defaultRegistrar(
  WebMcpTool tool, {
  List<String> exposedTo = const [],
}) =>
    WebMcp.registerTool(tool, exposedTo: exposedTo);
