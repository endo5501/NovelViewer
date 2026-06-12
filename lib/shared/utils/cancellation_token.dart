/// Thrown by [CancellationToken.throwIfCancelled] when cancellation has been
/// requested. Callers that want to distinguish a user-initiated cancellation
/// from a genuine failure should catch this type specifically.
class CancelledException implements Exception {
  final String message;
  const CancelledException([this.message = 'Operation was cancelled']);

  @override
  String toString() => 'CancelledException: $message';
}

/// A lightweight, general-purpose cooperative cancellation primitive.
///
/// Long-running operations check [isCancelled] / [throwIfCancelled] at safe
/// points, and can register [onCancel] callbacks (e.g. to abort an in-flight
/// HTTP request by closing the client). This is intentionally independent of
/// the TTS FFI abort mechanism, which works at the native-pointer level.
class CancellationToken {
  bool _cancelled = false;
  final List<void Function()> _callbacks = [];

  bool get isCancelled => _cancelled;

  /// Requests cancellation. Idempotent: calling more than once has no extra
  /// effect. Registered [onCancel] callbacks run exactly once, on the first
  /// call.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    // Copy first so a callback that registers another callback can't mutate the
    // list mid-iteration.
    final callbacks = List<void Function()>.of(_callbacks);
    _callbacks.clear();
    for (final cb in callbacks) {
      cb();
    }
  }

  /// Registers a callback to run when the token is cancelled. If the token is
  /// already cancelled, [callback] runs immediately.
  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
      return;
    }
    _callbacks.add(callback);
  }

  /// Throws [CancelledException] if cancellation has been requested.
  void throwIfCancelled() {
    if (_cancelled) throw const CancelledException();
  }
}
