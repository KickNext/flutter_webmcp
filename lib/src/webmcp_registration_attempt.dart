import 'dart:async';

import 'webmcp_registration.dart';

/// A registration that can be cancelled before or after it becomes ready.
final class WebMcpRegistrationAttempt {
  /// Creates an attempt backed by [cancel].
  WebMcpRegistrationAttempt({
    required Future<WebMcpRegistration> ready,
    required FutureOr<void> Function() cancel,
  }) : _cancel = cancel {
    this.ready = ready.then((registration) {
      _registration = registration;
      return registration;
    });
  }

  /// Completes when the registration attempt finishes.
  late final Future<WebMcpRegistration> ready;

  final FutureOr<void> Function() _cancel;
  WebMcpRegistration? _registration;
  bool _isCancelled = false;
  Future<void>? _cancellation;

  /// Whether [cancel] has been called.
  bool get isCancelled => _isCancelled;

  /// Cancels this attempt or removes its active registration.
  ///
  /// Cancellation starts immediately. The returned future reflects completion
  /// of any adapter-specific asynchronous cleanup.
  Future<void> cancel() {
    if (_isCancelled) return _cancellation ?? Future<void>.value();
    _isCancelled = true;
    final registration = _registration;
    if (registration != null) {
      return _cancellation = registration.unregister();
    }
    return _cancellation = Future<void>.sync(_cancel);
  }
}
