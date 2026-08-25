/// A JSON-serializable result returned to a WebMCP agent.
final class WebMcpResult {
  const WebMcpResult._(this.value);

  /// Returns a standard MCP-style text content block.
  factory WebMcpResult.text(String text) => WebMcpResult._({
        'content': [
          {'type': 'text', 'text': text},
        ],
      });

  /// Returns structured data, optionally accompanied by explanatory text.
  factory WebMcpResult.structured(
    Object? data, {
    String? text,
  }) =>
      WebMcpResult._({
        if (text != null)
          'content': [
            {'type': 'text', 'text': text},
          ],
        'structuredContent': data,
      });

  /// Returns a raw JSON-compatible value without adding an envelope.
  factory WebMcpResult.json(Object? value) => WebMcpResult._(value);

  /// Returns a structured tool error that agents can understand.
  factory WebMcpResult.error({
    required String code,
    required String message,
    Object? details,
  }) =>
      WebMcpResult._({
        'isError': true,
        'content': [
          {'type': 'text', 'text': message},
        ],
        'error': {
          'code': code,
          'message': message,
          if (details != null) 'details': details,
        },
      });

  /// The JSON-compatible wire value represented by this result.
  final Object? value;

  /// Returns the value that is passed to the browser agent.
  Object? toJson() => value;
}
