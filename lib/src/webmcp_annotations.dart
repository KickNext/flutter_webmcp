/// Hints that help an agent handle a tool safely.
final class WebMcpAnnotations {
  /// Creates optional safety hints for a tool.
  const WebMcpAnnotations({
    this.readOnly,
    this.untrustedContent,
    this.consequential,
    this.debugging,
  });

  /// Whether the tool only reads state and has no side effects.
  final bool? readOnly;

  /// Whether the tool result can contain content from an untrusted source.
  final bool? untrustedContent;

  /// Whether execution can have significant or difficult-to-reverse effects.
  ///
  /// This is an agent hint, not a substitute for authorization or confirmation.
  final bool? consequential;

  /// Whether the tool is intended for debugging, testing, or developer tools.
  final bool? debugging;
}
