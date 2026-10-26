import 'package:dio/dio.dart';

import '../../core/api_contract.dart';
import '../../core/http_core.dart';
import '../../core/workspace_sleep.dart';

/// When a hosted workspace sleeps, as it says it. [sleeps] is false where it never stops itself (a workspace installed by its
/// owner, a server too old to say); otherwise [sleepsAt] is when it stops if nothing happens till then, on this device's clock,
/// or null while something holds it ([heldBy]: an execution going on, an update, work planned soon).
class WorkspaceSleep {
  const WorkspaceSleep({required this.sleeps, this.sleepsAt, this.heldBy, this.idleMinutes = 0});

  static const never = WorkspaceSleep(sleeps: false);

  final bool sleeps;
  final DateTime? sleepsAt;
  final String? heldBy;

  /// How long it stays up with nothing going on.
  final int idleMinutes;

  /// What the server said; its time read against its own clock, so that the time left is right whatever this device's clock.
  factory WorkspaceSleep.fromJson(Map<String, dynamic> json, {DateTime? receivedAt}) {
    final received = receivedAt ?? DateTime.now();
    final serverNow = DateTime.tryParse(json['now'] as String? ?? '');
    final at = DateTime.tryParse(json['sleepsAt'] as String? ?? '');
    final sleepsAt = at == null ? null : (serverNow == null ? at.toLocal() : received.add(at.difference(serverNow)));
    return WorkspaceSleep(
      sleeps: json['sleeps'] == true,
      sleepsAt: sleepsAt,
      heldBy: json['heldBy'] as String?,
      idleMinutes: (json['idleMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The sleep of a hosted workspace: when it sleeps, keep it awake, wake it. Asking when it sleeps is not activity (a tab left
/// open never keeps it up); [stayAwake] is. While the app shows it asleep, close [WorkspaceSleepGate] so that nothing wakes it by
/// itself, and [wake] it when the person asks.
class WorkspaceSleepApi {
  WorkspaceSleepApi(this._c);
  final AgentivityHttpCore _c;

  static const String _sleep = '/api/v1/hosting/sleep';
  static const String _awake = '/api/v1/hosting/awake';

  /// When it sleeps; [WorkspaceSleep.never] from a server that does not say.
  Future<WorkspaceSleep> read() async {
    try {
      final response = await _c.get<Map<String, dynamic>>(_sleep, options: Options(headers: {'Cache-Control': 'no-cache'}));
      return WorkspaceSleep.fromJson(response.data ?? const {});
    } on Object catch (error) {
      if (error is ApiException && (error.httpStatus == 404 || error.httpStatus == 405)) return WorkspaceSleep.never;
      rethrow;
    }
  }

  /// The person stays: the delay with nothing going on starts again.
  Future<WorkspaceSleep> stayAwake() async {
    final response = await _c.post<Map<String, dynamic>>(_awake);
    return WorkspaceSleep.fromJson(response.data ?? const {});
  }

  /// Wakes it (the gateway starts it at this call, waited for while it starts), then opens [WorkspaceSleepGate] again.
  Future<WorkspaceSleep> wake() async {
    final response = await _c.get<Map<String, dynamic>>(_sleep, options: Options(extra: {WorkspaceSleepGate.wakesKey: true}));
    WorkspaceSleepGate.wake();
    return WorkspaceSleep.fromJson(response.data ?? const {});
  }
}
