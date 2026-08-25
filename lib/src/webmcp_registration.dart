import 'dart:async';

/// A registered tool whose lifecycle can be ended with [unregister].
final class WebMcpRegistration {
  /// Creates a registration handle for [name].
  WebMcpRegistration(this.name, FutureOr<void> Function() unregister)
      : _unregister = unregister;

  /// Name of the registered tool.
  final String name;
  final FutureOr<void> Function() _unregister;
  bool _isRegistered = true;

  /// Whether [unregister] has not yet been called.
  bool get isRegistered => _isRegistered;

  /// Removes the tool. Calling this more than once has no effect.
  Future<void> unregister() async {
    if (!_isRegistered) return;
    _isRegistered = false;
    await _unregister();
  }
}
