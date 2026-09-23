import '../../core/http_core.dart';

/// Row-level access to shared Data Table assets — `/api/v1/datatables/{id}/rows`.
///
/// **Scope**: rows only (list/insert/update/delete), matching [AgentivityClient]'s
/// app-runtime boundary. Defining a table's schema, browsing/moving it between
/// folders, and versioning are Studio (admin) concerns — see
/// `AgentivityStudioClient.dataTableAdmin` — and deliberately not exposed here,
/// same reasoning as workflows/agents/teams/credentials.
///
/// This is how an app reads data a Team's workflow wrote to a shared table (e.g.
/// a `trips` table a Trip Manager populates, that a "my trips" screen lists
/// directly — no agent run needed just to display it) and, where the app owns
/// the write (not an agent), writes back to it.
class DataTablesApi {
  DataTablesApi(this._c);
  final AgentivityHttpCore _c;

  Future<List<Map<String, dynamic>>> fetchDataTableRows(
    String id, {
    String? whereColumn,
    String? whereValue,
  }) async {
    final normalizedId = _c.requireNormalizedId(id, label: 'Data Table id');
    final response = await _c.get<List<dynamic>>(
      AgentivityHttpCore.v1('/datatables/$normalizedId/rows'),
      queryParameters: <String, dynamic>{
        if (whereColumn != null && whereColumn.trim().isNotEmpty) 'whereColumn': whereColumn.trim(),
        if (whereValue != null) 'whereValue': whereValue,
      },
    );
    final payload = response.data ?? const <dynamic>[];
    return payload.whereType<Object>().map((entry) {
      if (entry is Map<String, dynamic>) return entry;
      if (entry is Map) return Map<String, dynamic>.from(entry);
      throw StateError('Unsupported data table row payload: ${entry.runtimeType}');
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> insertDataTableRow(String id, Map<String, dynamic> data) async {
    final normalizedId = _c.requireNormalizedId(id, label: 'Data Table id');
    final response = await _c.post<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/datatables/$normalizedId/rows'),
      data: data,
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateDataTableRow(String id, Object rowId, Map<String, dynamic> data) async {
    final normalizedId = _c.requireNormalizedId(id, label: 'Data Table id');
    final response = await _c.put<Map<String, dynamic>>(
      AgentivityHttpCore.v1('/datatables/$normalizedId/rows/$rowId'),
      data: data,
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<void> deleteDataTableRow(String id, Object rowId) async {
    final normalizedId = _c.requireNormalizedId(id, label: 'Data Table id');
    await _c.delete<void>(AgentivityHttpCore.v1('/datatables/$normalizedId/rows/$rowId'));
  }
}
