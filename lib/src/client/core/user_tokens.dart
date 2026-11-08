import 'dart:async';

import 'package:dio/dio.dart';

/// The token of a user of an API key (`agu_…`), worth a few minutes: got by your server, with the key, for one of your users, or
/// by signing in through the key for a person of the workspace. [expiresAt], when known, lets the client ask for the next one in time.
class UserToken {
  const UserToken(this.token, {this.expiresAt});

  /// As the instance gives it: `{ token, expiresAt }`.
  factory UserToken.fromJson(Map<String, dynamic> json) =>
      UserToken(json['token'] as String, expiresAt: json['expiresAt'] is String ? DateTime.tryParse(json['expiresAt'] as String) : null);

  final String token;
  final DateTime? expiresAt;
}

/// Asks for the next token of the user: your server again, or the instance for a person signed in through the key.
typedef RenewUserToken = Future<UserToken> Function();

/// The user a client speaks for, with their token: on every request (rather than the key), asked again a minute before its end and
/// when the instance refuses it (the request is then sent once more). A request whose `extra` holds [ownAuthorization] says its own.
class UserTokens extends Interceptor {
  UserTokens(this._dio);

  final Dio _dio;

  /// Set in a request's `extra`: it goes with the Authorization it says, never the user's token.
  static const String ownAuthorization = 'agentivity.ownAuthorization';
  static const String _retried = 'agentivity.userTokenRetried';
  static const Duration _renewBefore = Duration(minutes: 1);

  UserToken? _token;
  RenewUserToken? _renew;
  Future<String>? _renewing;
  Object? _keyHeader;
  bool _keyKept = false;

  /// The token of the user the client speaks for, if any.
  String? get current => _token?.token;

  /// Speaks for a user from now on; without a token yet, [renew] is asked for one at the first request. `null` and no [renew]: the
  /// client speaks for no user any more, and goes with its key again.
  void set(UserToken? token, RenewUserToken? renew) {
    if (!_keyKept) {
      _keyHeader = _dio.options.headers['Authorization'];
      _keyKept = true;
    }
    _token = token;
    _renew = renew;
    _renewing = null;
    _show();
  }

  // What goes with what does not pass through here (a stream on the web reads the headers of the client): the token, or the key.
  void _show() {
    final shown = _token != null ? 'Bearer ${_token!.token}' : (_renew == null ? _keyHeader : null);
    if (shown == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = shown;
    }
  }

  bool get _speaksForAUser => _token != null || _renew != null;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[ownAuthorization] == true || !_speaksForAUser) return handler.next(options);
    try {
      final ends = _token?.expiresAt;
      final token = _renew != null && (_token == null || (ends != null && ends.difference(DateTime.now()) < _renewBefore)) ? await _renewNow() : _token!.token;
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } catch (error) {
      handler.reject(error is DioException ? error : DioException(requestOptions: options, error: error));
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (_renew == null || options.extra[ownAuthorization] == true || options.extra[_retried] == true || !_refusedToken(err.response)) return handler.next(err);
    try {
      final token = await _renewNow();
      final again = options.copyWith(headers: {...options.headers, 'Authorization': 'Bearer $token'}, extra: {...options.extra, _retried: true});
      handler.resolve(await _dio.fetch<dynamic>(again));
    } on DioException catch (again) {
      handler.next(again);
    } catch (_) {
      handler.next(err);
    }
  }

  // Whether the instance refused the request for its user token (wrong, or past its end), rather than for anything else.
  static bool _refusedToken(Response<dynamic>? response) {
    final data = response?.data;
    return response?.statusCode == 401 && data is Map && data['error'] == 'invalid_user_token';
  }

  // One renewal at a time: the requests that wait for it all go with the token it brings.
  Future<String> _renewNow() {
    final renew = _renew!;
    return _renewing ??= renew().then((next) {
      _token = next;
      _show();
      return next.token;
    }).whenComplete(() => _renewing = null);
  }
}
