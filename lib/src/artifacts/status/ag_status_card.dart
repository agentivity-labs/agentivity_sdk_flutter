import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';

/// Status / alert card (success, warning, error, info).
///
/// Agent props:
/// ```json
/// {
///   "title": "Deployment complete",
///   "status": "success",
///   "message": "Version 2.4.1 deployed to production in 38 s.",
///   "details": ["3 services restarted", "Health checks passed"]
/// }
/// ```
/// [status] can be "success", "warning", "error" or "info" (default).
class AgStatusCard extends StatelessWidget {
  const AgStatusCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = props['title'] as String? ?? 'Status';
    final status = props['status'] as String? ?? 'info';
    final message = props['message']?.toString() ?? '';
    final details = (props['details'] as List?)?.map((e) => e.toString()).toList() ?? [];

    final (color, icon) = switch (status) {
      'success' => (const Color(0xFF10b981), Icons.check_circle_rounded),
      'warning' => (const Color(0xFFf59e0b), Icons.warning_rounded),
      'error'   => (const Color(0xFFef4444), Icons.error_rounded),
      _          => (cs.primary,              Icons.info_rounded),
    };

    return AgArtifactCard(
      title: title,
      type: _statusLabel(status),
      icon: icon,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...details.map((d) => Padding(
                    padding: const EdgeInsets.only(left: 24, top: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'success' => 'Success',
        'warning' => 'Warning',
        'error'   => 'Error',
        _          => 'Info',
      };
}
