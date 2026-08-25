import 'dart:async';

import 'webmcp_annotations.dart';

/// Handles a tool call with raw JSON object input.
typedef WebMcpToolHandler = FutureOr<Object?> Function(
  Map<String, Object?> input,
  WebMcpExecutionContext context,
);

/// Converts raw JSON object input into an application-specific type.
typedef WebMcpInputDecoder<T> = T Function(Map<String, Object?> input);

/// Handles a tool call after its input has been decoded to [T].
typedef WebMcpTypedToolHandler<T> = FutureOr<Object?> Function(
  T input,
  WebMcpExecutionContext context,
);

/// Information associated with one invocation of a tool.
final class WebMcpExecutionContext {
  /// Creates execution state backed by a live cancellation callback.
  const WebMcpExecutionContext({required bool Function() isCancelled})
      : _isCancelled = isCancelled;

  final bool Function() _isCancelled;

  /// Whether the browser agent cancelled this invocation.
  bool get isCancelled => _isCancelled();
}

/// A tool exposed by the current web page to browser agents.
class WebMcpTool {
  /// Creates a WebMCP tool definition.
  const WebMcpTool({
    required this.name,
    required this.description,
    required this.execute,
    this.title,
    this.inputSchema = const <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{},
    },
    this.annotations,
  });

  /// Stable identifier. May contain ASCII letters, digits, `_`, `-`, and `.`.
  final String name;

  /// Optional human-readable label shown by the user agent.
  final String? title;

  /// Natural-language explanation of when and how the tool should be used.
  final String description;

  /// JSON Schema describing the arguments accepted by [execute].
  final Map<String, Object?> inputSchema;

  /// Optional hints that help an agent handle the tool safely.
  final WebMcpAnnotations? annotations;

  /// Function invoked when an agent calls this tool.
  final WebMcpToolHandler execute;
}

/// A [WebMcpTool] that decodes its JSON input into an application type.
final class WebMcpTypedTool<T> extends WebMcpTool {
  /// Creates a tool that decodes raw input before invoking [execute].
  WebMcpTypedTool({
    required super.name,
    required super.description,
    required WebMcpInputDecoder<T> decodeInput,
    required WebMcpTypedToolHandler<T> execute,
    super.title,
    super.inputSchema,
    super.annotations,
  }) : super(
          execute: (input, context) => execute(decodeInput(input), context),
        );
}
