import '../../core/http_core.dart';
import '../domain/desk_models.dart';

/// Signing in to an instance as a person: who is signed in, signing in and out, joining by an invitation, a new password, a new
/// address. The session is the cookie of the instance, kept by the browser (an app on the web served by the instance).
///
/// Part of [AgentivityPlatformClient].
class AccountApi {
  AccountApi(this._c);
  final AgentivityHttpCore _c;

  // GET /api/v1/auth/status
  Future<AccountStatus> status() async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/auth/status'));
    return AccountStatus.fromJson(response.data ?? const {});
  }

  // POST /api/v1/auth/sign-in
  Future<void> signIn({required String email, required String password}) async {
    await _c.post<dynamic>(AgentivityHttpCore.v1('/auth/sign-in'), data: {'email': email, 'password': password});
  }

  // POST /api/v1/auth/sign-out
  Future<void> signOut() async {
    await _c.post<dynamic>(AgentivityHttpCore.v1('/auth/sign-out'));
  }

  /// The address an invitation was sent to; null when the instance does not say.
  // GET /api/v1/auth/invitations/{token}
  Future<String?> invitationEmail(String token) async {
    final response = await _c.get<Map<String, dynamic>>(AgentivityHttpCore.v1('/auth/invitations/${Uri.encodeComponent(token)}'));
    return (response.data ?? const {})['email'] as String?;
  }

  /// Joins the instance by an invitation: the person chooses their name and their password.
  // POST /api/v1/auth/invitations/accept
  Future<void> acceptInvitation({required String token, required String name, required String password}) async {
    await _c.post<dynamic>(AgentivityHttpCore.v1('/auth/invitations/accept'), data: {'token': token, 'name': name, 'password': password});
  }

  /// Asks for a link to choose a new password, sent to [email] in [language].
  // POST /api/v1/auth/password-reset/request
  Future<void> requestPasswordReset({required String email, required String language}) async {
    await _c.post<dynamic>(AgentivityHttpCore.v1('/auth/password-reset/request'), data: {'email': email, 'language': language});
  }

  // POST /api/v1/auth/password-reset
  Future<void> resetPassword({required String token, required String password}) async {
    await _c.post<dynamic>(AgentivityHttpCore.v1('/auth/password-reset'), data: {'token': token, 'password': password});
  }

  /// Confirms a new address from the link sent to it; the address confirmed.
  // POST /api/v1/auth/email/confirm
  Future<String?> confirmEmail({required String token, required String language}) async {
    final response = await _c.post<Map<String, dynamic>>(AgentivityHttpCore.v1('/auth/email/confirm'), data: {'token': token, 'language': language});
    return (response.data ?? const {})['email'] as String?;
  }
}
