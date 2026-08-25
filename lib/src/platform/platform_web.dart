@JS()
library;

import 'dart:convert';
import 'dart:js_interop';

import '../webmcp_exception.dart';
import '../webmcp_logging.dart';
import '../webmcp_registration.dart';
import '../webmcp_result.dart';
import '../webmcp_support.dart';
import '../webmcp_tool.dart';
import 'platform.dart';

/// Creates the browser platform adapter.
WebMcpPlatform createWebMcpPlatform() => const _BrowserWebMcpPlatform();

final class _BrowserWebMcpPlatform implements WebMcpPlatform {
  const _BrowserWebMcpPlatform();

  _ModelContext? get _modelContext => _document.modelContext;

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
  Future<WebMcpRegistration> registerTool(
    WebMcpTool tool, {
    List<String> exposedTo = const [],
  }) async {
    final modelContext = _modelContext;
    if (modelContext == null) {
      throw const WebMcpException(
        'This browser does not expose document.modelContext.',
      );
    }

    final controller = _AbortController();
    final annotations = tool.annotations;
    final jsTool = _ModelContextTool(
      name: tool.name,
      title: tool.title,
      description: tool.description,
      inputSchema: tool.inputSchema.jsify() as JSObject,
      annotations: annotations == null
          ? null
          : _ToolAnnotations(
              readOnlyHint: annotations.readOnly,
              untrustedContentHint: annotations.untrustedContent,
            ),
      execute: ((JSObject input, [_ExecuteOptions? options]) =>
          _execute(tool, input, options).toJS).toJS,
    );
    final options = _RegisterOptions(
      signal: controller.signal,
      exposedTo: exposedTo.map((origin) => origin.toJS).toList().toJS,
    );

    try {
      await modelContext.registerTool(jsTool, options).toDart;
    } catch (error) {
      throw WebMcpException('Could not register tool `${tool.name}`.', error);
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
  external JSPromise<JSAny?> registerTool(
    _ModelContextTool tool, [
    _RegisterOptions options,
  ]);
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
    _ToolAnnotations? annotations,
  });
}

@JS()
@anonymous
extension type _ToolAnnotations._(JSObject _) implements JSObject {
  external factory _ToolAnnotations({
    bool? readOnlyHint,
    bool? untrustedContentHint,
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
