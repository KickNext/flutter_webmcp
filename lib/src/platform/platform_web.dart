@JS()
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../webmcp_exception.dart';
import '../webmcp_lifecycle_event.dart';
import '../webmcp_logging.dart';
import '../webmcp_registration.dart';
import '../webmcp_registration_attempt.dart';
import '../webmcp_result.dart';
import '../webmcp_support.dart';
import '../webmcp_tool.dart';
import 'platform.dart';

/// Creates the browser platform adapter.
WebMcpPlatform createWebMcpPlatform() => const _BrowserWebMcpPlatform();

final class _BrowserWebMcpPlatform implements WebMcpPlatform {
  const _BrowserWebMcpPlatform();

  _ModelContext? get _modelContext => _document.modelContext;

  bool _supportsLifecycleEvents(_ModelContext? context) =>
      support.isSupported &&
      context != null &&
      context.hasProperty('ontoolactivated'.toJS).toDart &&
      context.hasProperty('ontoolcancel'.toJS).toDart &&
      context.getProperty<JSAny?>('addEventListener'.toJS).isA<JSFunction>() &&
      context.getProperty<JSAny?>('removeEventListener'.toJS).isA<JSFunction>();

  @override
  bool get isLifecycleEventsSupported =>
      _supportsLifecycleEvents(_modelContext);

  @override
  Stream<WebMcpLifecycleEvent> get lifecycleEvents {
    final context = _modelContext;
    if (!_supportsLifecycleEvents(context)) return const Stream.empty();
    final modelContext = context!;
    late final StreamController<WebMcpLifecycleEvent> controller;
    final activated = ((_ToolEvent event) {
      controller.add(WebMcpLifecycleEvent(
        type: WebMcpLifecycleEventType.activated,
        toolName: event.toolName,
      ));
    }).toJS;
    final cancelled = ((_ToolEvent event) {
      controller.add(WebMcpLifecycleEvent(
        type: WebMcpLifecycleEventType.cancelled,
        toolName: event.toolName,
      ));
    }).toJS;
    controller = StreamController<WebMcpLifecycleEvent>.broadcast(
      onListen: () {
        modelContext.addEventListener('toolactivated', activated);
        modelContext.addEventListener('toolcancel', cancelled);
      },
      onCancel: () {
        modelContext.removeEventListener('toolactivated', activated);
        modelContext.removeEventListener('toolcancel', cancelled);
      },
    );
    return controller.stream;
  }

  @override
  WebMcpSupport get support {
    if (!_isSecureContext) {
      return const WebMcpSupport(
        WebMcpSupportStatus.insecureContext,
        'WebMCP requires a secure context such as HTTPS or localhost.',
      );
    }
    if (_modelContext == null) {
      return const WebMcpSupport(
        WebMcpSupportStatus.browserApiUnavailable,
        'This browser does not expose document.modelContext.',
      );
    }
    return const WebMcpSupport(
      WebMcpSupportStatus.supported,
      'WebMCP is available.',
    );
  }

  @override
  WebMcpRegistrationAttempt startToolRegistration(
    WebMcpTool tool, {
    required List<String> exposedTo,
  }) {
    final controller = _AbortController();
    return WebMcpRegistrationAttempt(
      ready: _registerTool(tool, exposedTo, controller),
      cancel: () => controller.abort(),
    );
  }

  Future<WebMcpRegistration> _registerTool(
    WebMcpTool tool,
    List<String> exposedTo,
    _AbortController controller,
  ) async {
    final modelContext = _modelContext;
    if (modelContext == null) {
      throw const WebMcpException(
        'This browser does not expose document.modelContext.',
      );
    }

    final annotations = tool.annotations;
    final jsAnnotations = annotations == null ? null : JSObject();
    if (annotations != null) {
      final hints = {
        'readOnlyHint': annotations.readOnly,
        'untrustedContentHint': annotations.untrustedContent,
        'consequentialHint': annotations.consequential,
        'debugging': annotations.debugging,
      };
      for (final entry in hints.entries) {
        final value = entry.value;
        if (value != null) {
          jsAnnotations!.setProperty(entry.key.toJS, value.toJS);
        }
      }
    }
    final jsTool = _ModelContextTool(
      name: tool.name,
      title: tool.title,
      description: tool.description,
      inputSchema: tool.inputSchema.jsify() as JSObject,
      annotations: jsAnnotations,
      execute: ((JSObject input, [_ExecuteOptions? options]) =>
          _execute(tool, input, options).toJS).toJS,
    );
    final options = _RegisterOptions(
      signal: controller.signal,
      exposedTo: exposedTo.map((origin) => origin.toJS).toList().toJS,
    );

    try {
      final result = modelContext.registerTool(jsTool, options);
      if (result.isDefinedAndNotNull && result.isA<JSPromise<JSAny?>>()) {
        await (result as JSPromise<JSAny?>).toDart;
      }
    } catch (error) {
      if (controller.signal.aborted) {
        throw WebMcpException(
          'Registration of tool `${tool.name}` was cancelled.',
          error,
        );
      }
      throw WebMcpException('Could not register tool `${tool.name}`.', error);
    }

    if (controller.signal.aborted) {
      throw WebMcpException(
        'Registration of tool `${tool.name}` was cancelled.',
      );
    }

    return WebMcpRegistration(tool.name, () => controller.abort());
  }

  Future<JSAny?> _execute(
    WebMcpTool tool,
    JSObject input,
    _ExecuteOptions? options,
  ) async {
    final stopwatch = Stopwatch()..start();
    Map<String, Object?> dartInput = const {};
    try {
      dartInput = _stringKeyedMap(input.dartify());
      final result = await tool.execute(
        dartInput,
        WebMcpExecutionContext(
          isCancelled: () => options?.signal?.aborted ?? false,
        ),
      );
      final wireResult = result is WebMcpResult ? result.toJson() : result;
      jsonEncode(wireResult);
      stopwatch.stop();
      emitWebMcpLog(
        WebMcpToolCallEvent(
          toolName: tool.name,
          input: dartInput,
          status: WebMcpToolCallStatus.succeeded,
          duration: stopwatch.elapsed,
          result: wireResult,
        ),
      );
      return wireResult.jsify();
    } catch (error, stackTrace) {
      stopwatch.stop();
      emitWebMcpLog(
        WebMcpToolCallEvent(
          toolName: tool.name,
          input: dartInput,
          status: WebMcpToolCallStatus.failed,
          duration: stopwatch.elapsed,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      final errorResult = switch (error) {
        WebMcpToolException(:final code, :final message, :final details) =>
          WebMcpResult.error(
            code: code,
            message: message,
            details: details,
          ),
        _ => WebMcpResult.error(
            code: 'internal_error',
            message: 'Tool `${tool.name}` failed.',
          ),
      };
      return errorResult.toJson().jsify();
    }
  }
}

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is! Map) {
    throw const WebMcpException('Tool input must be a JSON object.');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

@JS('document')
external _Document get _document;

@JS('isSecureContext')
external bool get _isSecureContext;

extension type _Document._(JSObject _) implements JSObject {
  external _ModelContext? get modelContext;
}

extension type _ModelContext._(JSObject _) implements JSObject {
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
  external JSAny? registerTool(
    _ModelContextTool tool, [
    _RegisterOptions options,
  ]);
}

extension type _ToolEvent._(JSObject _) implements JSObject {
  external String get toolName;
}

@JS()
@anonymous
extension type _ModelContextTool._(JSObject _) implements JSObject {
  external factory _ModelContextTool({
    required String name,
    String? title,
    required String description,
    required JSObject inputSchema,
    required JSFunction execute,
    JSObject? annotations,
  });
}

@JS()
@anonymous
extension type _RegisterOptions._(JSObject _) implements JSObject {
  external factory _RegisterOptions({
    required _AbortSignal signal,
    required JSArray<JSString> exposedTo,
  });
}

@JS()
@anonymous
extension type _ExecuteOptions._(JSObject _) implements JSObject {
  external _AbortSignal? get signal;
}

@JS('AbortController')
extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external _AbortSignal get signal;
  external void abort();
}

extension type _AbortSignal._(JSObject _) implements JSObject {
  external bool get aborted;
}
