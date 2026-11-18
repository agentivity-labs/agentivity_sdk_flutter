import 'package:dio/dio.dart';

/// Says on every call how far from UTC this device is, so that the service can cut dates into days, weeks and months the way the
/// person reading them lives them — without anybody having to set anything, and whatever country each of them sits in.
///
/// Only the cutting: dates themselves travel in UTC both ways, and the words a date is written in are written by the page that
/// shows it, which is the only side that knows the language it is read in.
///
/// It is read only when the platform names no place of its own: a workspace that chooses one place uses it for everyone (see the
/// Place and time settings). Nothing here says where the person is beyond the offset their own clock already shows.
class WhereWeAreInterceptor extends Interceptor {
  /// The header the service reads: minutes from UTC, counted as a browser counts them (Paris in winter: 60).
  static const header = 'X-Agentivity-Utc-Offset';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[header] = DateTime.now().timeZoneOffset.inMinutes.toString();
    handler.next(options);
  }
}
