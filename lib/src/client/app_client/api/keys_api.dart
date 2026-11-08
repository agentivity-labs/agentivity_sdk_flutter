import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/http_core.dart';
import '../../core/user_tokens.dart';

/// A person of the workspace, signed in through a system whose API key lets its people in.
class KeySignedIn {
  const KeySignedIn({required this.token, required this.userId, required this.name, required this.email});

  final UserToken token;
  final String userId;
  final String name;
  final String email;
}

/// Where an app keeps its visitor of a demo between visits (shared_preferences, a file…); in memory unless it gives one.
abstract interface class VisitorStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class _MemoryVisitorStore implements VisitorStore {
  final Map<String, String> _kept = {};

  @override
  Future<String?> read(String key) async => _kept[key];

  @override
  Future<void> write(String key, String value) async => _kept[key] = value;
}

/// The users of an API key, each with their own conversations. A key lives on a server, never in an app on people's devices: its
/// server asks the instance for its users' tokens (`POST /api/v1/keys/user-tokens`, `POST /api/v1/keys/visitors`), and the app
/// speaks for them with those.
///
/// - The users of your system: your server gets a token for each, and the app gives it with `client.setUserToken(token, renew: …)`,
///   `renew` asking your server for the next one.
/// - People of the workspace (an internal app): they sign in through the key ([signIn]); the client then renews their token itself
///   while their session lasts, and [signOut] ends it.
/// - Visitors of a demo: anonymous, each app keeps its own ([visitDemo]), asked of the demo's server.
class KeysApi {
  KeysApi(this._c);
  final AgentivityHttpCore _c;

  /// Signs a person of the workspace in through the key [keyId] (its id, never the key): from now on the client speaks for them,
  /// and renews their token while their session lasts. POST /api/v1/keys/{keyId}/sign-in
  Future<KeySignedIn> signIn({required String keyId, required String email, required String password}) async {
    // Signing in goes with nothing: neither a key nor the token of whoever the client spoke for before.
    final response = await _c.post<Map<String, dynamic>>(_path(keyId, '/sign-in'), data: {'email': email, 'password': password}, options: _own(null));
    final data = response.data ?? const <String, dynamic>{};
    final user = Map<String, dynamic>.from(data['user'] as Map? ?? const {});
    final token = UserToken.fromJson(data);
    _c.userTokens.set(token, () => renew(keyId));
    return KeySignedIn(token: token, userId: user['id'] as String? ?? '', name: user['name'] as String? ?? '', email: user['email'] as String? ?? '');
  }

  /// Signs out: the session and its tokens end, and the client speaks for no one. POST /api/v1/keys/{keyId}/sign-out
  Future<void> signOut(String keyId) async {
    final token = _c.userTokens.current;
    _c.userTokens.set(null, null);
    if (token != null) await _c.post<dynamic>(_path(keyId, '/sign-out'), options: _own(token));
  }

  /// The next token of the person signed in through the key, while their session lasts. POST /api/v1/keys/{keyId}/user-tokens/renew
  Future<UserToken> renew(String keyId) async {
    final response = await _c.post<Map<String, dynamic>>(_path(keyId, '/user-tokens/renew'), options: _own(_c.userTokens.current));
    return UserToken.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// Speaks for a visitor of a demo: the one [store] already keeps, or a new one that [getVisitor] asks of the demo's server (which
  /// keeps the key), kept for the days the demo keeps what they start, so that they find their conversations again; a new one is
  /// asked when it ends or is refused.
  void visitDemo(Future<UserToken> Function() getVisitor, {VisitorStore? store, String storeKey = 'agentivity.visitor'}) {
    final kept = store ?? _MemoryVisitorStore();
    _c.userTokens.set(null, () async {
      // The one kept serves, unless it is the one the client now asks to replace (past its end, or refused).
      final raw = await kept.read(storeKey);
      if (raw != null) {
        try {
          final known = UserToken.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
          final ends = known.expiresAt;
          if (known.token != _c.userTokens.current && (ends == null || ends.difference(DateTime.now()) > const Duration(minutes: 1))) return known;
        } on FormatException {
          // Not what was kept: a new visitor.
        }
      }
      final given = await getVisitor();
      await kept.write(storeKey, jsonEncode({'token': given.token, 'expiresAt': given.expiresAt?.toUtc().toIso8601String()}));
      return given;
    });
  }

  static Options _own(String? token) => Options(extra: {UserTokens.ownAuthorization: true}, headers: {'Authorization': token == null ? '' : 'Bearer $token'});

  static String _path(String keyId, String rest) => AgentivityHttpCore.v1('/keys/${Uri.encodeComponent(keyId)}$rest');
}
