import 'package:dio/dio.dart';

/// A hosted workspace sleeps when nobody uses it, and starts again at the next call. While it starts, the gateway answers 502, 503
/// or 504: a read is asked again, as long as `Retry-After` says (3 s when it says nothing), for [mostWait] in all. A write (POST,
/// PUT, PATCH, DELETE) is never sent twice: it is not known whether it arrived.
class WakingWorkspaceInterceptor extends Interceptor {
  WakingWorkspaceInterceptor(this._dio, {this.mostWait = const Duration(minutes: 1)});

  final Dio _dio;

  /// How long a read waits for the workspace, in all.
  final Duration mostWait;

  static const String _startedAt = 'agentivity.waking.startedAt';

  /// How long to wait before asking again, or null to give the answer as it is.
  static Duration? waitBeforeAskingAgain(String method, int? status, String? retryAfter, Duration waited, Duration mostWait) {
    if (method != 'GET' && method != 'HEAD') return null;
    if (status != 502 && status != 503 && status != 504) return null;
    final said = int.tryParse(retryAfter?.trim() ?? '');
    final wait = said != null && said > 0 ? Duration(seconds: said.clamp(1, 10)) : const Duration(seconds: 3);
    return waited + wait > mostWait ? null : wait;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final startedAt = options.extra[_startedAt] as DateTime? ?? DateTime.now();
    final wait = waitBeforeAskingAgain(
      options.method.toUpperCase(),
      err.response?.statusCode,
      err.response?.headers.value('retry-after'),
      DateTime.now().difference(startedAt),
      mostWait,
    );
    if (wait == null || options.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(wait);
    try {
      handler.resolve(await _dio.fetch<dynamic>(options..extra[_startedAt] = startedAt));
    } on DioException catch (again) {
      handler.next(again);
    }
  }
}
