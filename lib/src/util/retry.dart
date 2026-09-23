/// Retries [fn] with exponential backoff on failure — for a critical one-shot call (start a
/// run, submit a reply, load data the user is waiting on) where a single transient blip
/// (a real-world network drop, a mobile network handoff, a momentary backend hiccup)
/// shouldn't surface as a hard failure. Not for streaming connections — see
/// `AgUiSseChannel` for that, which has its own reconnect/backoff and reacts to the app
/// resuming from the background.
Future<T> retryWithBackoff<T>(
  Future<T> Function() fn, {
  int retries = 3,
  Duration baseDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 8),

  /// Return false to fail fast instead of retrying (e.g. a validation error that retrying can't fix). Default: always retryable.
  bool Function(Object error)? isRetryable,

  /// Called before each wait, e.g. to update a "retrying…" UI state.
  void Function(Object error, int attempt, Duration delay)? onRetry,
}) async {
  var attempt = 0;
  while (true) {
    try {
      return await fn();
    } on Object catch (error) {
      if (attempt >= retries || (isRetryable != null && !isRetryable(error))) rethrow;
      final backoffMs = baseDelay.inMilliseconds * (1 << attempt);
      final cappedMs = backoffMs < maxDelay.inMilliseconds ? backoffMs : maxDelay.inMilliseconds;
      final jitterMs = DateTime.now().millisecondsSinceEpoch % 250;
      final delay = Duration(milliseconds: cappedMs + jitterMs);
      onRetry?.call(error, attempt + 1, delay);
      await Future<void>.delayed(delay);
      attempt += 1;
    }
  }
}
