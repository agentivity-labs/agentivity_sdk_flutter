import 'dart:async';

import 'package:flutter/foundation.dart';

import 'workspace_sleep.dart';

/// Since when a call has been waiting for its answer longer than [after], or null when none is: what an app shows as "Just a
/// moment…" ([AgUiWaitNotice]). A hosted workspace that sleeps holds the first calls while it starts, often for most of a minute;
/// a call that is long by itself waits the same. A call is followed whole, the times it is asked again included. A live stream,
/// and a read the app makes by itself ([WorkspaceSleepGate.inBackground]), are not waited for by a person: not followed.
class SlowCalls extends ValueNotifier<DateTime?> {
  SlowCalls({this.after = const Duration(seconds: 3)}) : super(null);

  /// How long a call waits before it counts.
  final Duration after;

  final Map<Object, DateTime> _slow = {};

  /// Runs [call], counted while it waits past [after].
  Future<T> follow<T>(Future<T> Function() call) async {
    if (WorkspaceSleepGate.readingInBackground) return call();
    final id = Object();
    final started = DateTime.now();
    final timer = Timer(after, () {
      _slow[id] = started;
      _recompute();
    });
    try {
      return await call();
    } finally {
      timer.cancel();
      if (_slow.remove(id) != null) _recompute();
    }
  }

  void _recompute() => value = _slow.isEmpty ? null : _slow.values.reduce((a, b) => a.isBefore(b) ? a : b);
}
