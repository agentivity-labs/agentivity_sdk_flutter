import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';

/// Says on every call how far from UTC this device is, so that the service can cut dates into days, weeks and months the way the
/// person reading them lives them — without anybody having to set anything, and whatever country each of them sits in.
///
/// It is read only when the platform names no place of its own: a workspace that chooses one place uses it for everyone (see the
/// Place and time settings). Nothing here says where the person is beyond the offset their own clock already shows.
class WhereWeAreInterceptor extends Interceptor {
  /// The header the service reads: minutes from UTC, counted as a browser counts them (Paris in winter: 60).
  static const header = 'X-Agentivity-Utc-Offset';

  /// And how this device writes a date: its language and country (fr-FR), so that a month is named the way it is read.
  static const localeHeader = 'X-Agentivity-Locale';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[header] = DateTime.now().timeZoneOffset.inMinutes.toString();
    final locale = PlatformDispatcher.instance.locale;
    options.headers[localeHeader] = locale.countryCode == null ? locale.languageCode : '${locale.languageCode}-${locale.countryCode}';
    handler.next(options);
  }
}
