import 'package:dio/dio.dart';

import '../../core/http_core.dart';
import '../../core/user_tokens.dart';

/// A person of the instance, signed in through an App.
class AppSignedIn {
  const AppSignedIn({required this.token, required this.userId, required this.name, required this.email});

  final UserToken token;
  final String userId;
  final String name;
  final String email;
}

/// The users of an App, each with their own conversations.
///
/// - The App's own users: the App's **server** gets a token for each (`POST /api/v1/apps/{id}/user-tokens` with its secret, never
///   from an app on people's devices), and the app gives it with `client.setUserToken(token, renew: …)`, `renew` asking its
///   server for the next one.
/// - People of the instance (an internal app): they sign in through the App ([signIn]); the client then renews their token itself
///   while their session lasts, and [signOut] ends it.
class AppsApi {
  AppsApi(this._c);
  final AgentivityHttpCore _c;

  /// Signs a person of the instance in through the App [appId]: from now on the client speaks for them, and renews their token
  /// while their session lasts. POST /api/v1/apps/{appId}/sign-in
  Future<AppSignedIn> signIn({required String appId, required String email, required String password}) async {
    // Signing in goes with nothing: neither a key nor the token of whoever the client spoke for before.
    final response = await _c.post<Map<String, dynamic>>(_path(appId, '/sign-in'), data: {'email': email, 'password': password}, options: _own(null));
    final data = response.data ?? const <String, dynamic>{};
    final user = Map<String, dynamic>.from(data['user'] as Map? ?? const {});
    final token = UserToken.fromJson(data);
    _c.userTokens.set(token, () => renew(appId));
    return AppSignedIn(token: token, userId: user['id'] as String? ?? '', name: user['name'] as String? ?? '', email: user['email'] as String? ?? '');
  }

  /// Signs out of the App: its session and its tokens end, and the client speaks for no one. POST /api/v1/apps/{appId}/sign-out
  Future<void> signOut(String appId) async {
    final token = _c.userTokens.current;
    _c.userTokens.set(null, null);
    if (token != null) await _c.post<dynamic>(_path(appId, '/sign-out'), options: _own(token));
  }

  /// The next token of the person signed in through the App, while their session lasts. POST /api/v1/apps/{appId}/user-tokens/renew
  Future<UserToken> renew(String appId) async {
    final response = await _c.post<Map<String, dynamic>>(_path(appId, '/user-tokens/renew'), options: _own(_c.userTokens.current));
    return UserToken.fromJson(response.data ?? const <String, dynamic>{});
  }

  static Options _own(String? token) => Options(extra: {UserTokens.ownAuthorization: true}, headers: {'Authorization': token == null ? '' : 'Bearer $token'});

  static String _path(String appId, String rest) => AgentivityHttpCore.v1('/apps/${Uri.encodeComponent(appId)}$rest');
}
