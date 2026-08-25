/// Hints that help an agent handle a tool safely.
final class WebMcpAnnotations {
  /// Creates optional safety hints for a tool.
  const WebMcpAnnotations({
    this.readOnly,
    this.untrustedContent,
  });

  /// Whether the tool only reads state and has no side effects.
  final bool? readOnly;

  /// Whether the tool result can contain content from an untrusted source.
  final bool? untrustedContent;
}
