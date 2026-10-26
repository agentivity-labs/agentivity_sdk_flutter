import 'dart:async';

import 'package:dio/dio.dart';

/// A hosted workspace that sleeps is started again by the first call it gets: the gateway wakes it. While the app shows it asleep,
/// nothing must reach it by itself — a list read again, a stream opened again, the probe of an unreachable server — or it would
/// never stay asleep. The app closes this gate when it says the workspace sleeps, and opens it when the person wakes it; a request
/// marked [wakesKey] (in its `extra`) goes through all the same.
///
/// One gate for the whole app: an app speaks to one workspace.
class WorkspaceSleepGate {
  WorkspaceSleepGate._();

  /// In a request's `extra`: this request is the one that wakes the workspace.
  static const String wakesKey = 'agentivity.wakes';

  static bool _asleep = false;

  /// True while the app holds back what it would send.
  static bool get asleep => _asleep;

  /// The app says the workspace sleeps: what it would send is held back from now on.
  static void fallAsleep() => _asleep = true;

  /// The person woke it: requests and streams go again.
  static void wake() => _asleep = false;

  /// Whether this request is held back now.
  static bool holdsBack(RequestOptions options) => _asleep && options.extra[wakesKey] != true;

  /// On a read the app makes by itself, not for a person (a list read again, figures followed): the workspace does not count it
  /// as activity, so that a tab left open lets it sleep.
  static const String backgroundHeader = 'X-Agentivity-Background';

  static final Object _background = Object();

  /// Runs [read] as the app's own: every request it sends is marked [backgroundHeader]. What a person asks is never run so.
  static Future<T> inBackground<T>(Future<T> Function() read) => runZoned(read, zoneValues: {_background: true});

  /// Whether the code running now reads in the background ([inBackground]).
  static bool get readingInBackground => Zone.current[_background] == true;

  /// What a request held back fails with: as if the server could not be reached, so that a stream tries again later, on its own
  /// schedule, and connects once the workspace is woken.
  static DioException refusal(RequestOptions options) =>
      DioException.connectionError(requestOptions: options, reason: 'The workspace sleeps: nothing is sent to it until it is woken.');
}

/// Holds back every request while the workspace sleeps, and marks the reads made in the background (see [WorkspaceSleepGate]).
class SleepingWorkspaceInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (WorkspaceSleepGate.holdsBack(options)) {
      handler.reject(WorkspaceSleepGate.refusal(options), true);
      return;
    }
    if (WorkspaceSleepGate.readingInBackground) options.headers[WorkspaceSleepGate.backgroundHeader] = '1';
    handler.next(options);
  }
}
