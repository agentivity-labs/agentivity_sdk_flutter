import 'dart:convert';

import 'package:flutter/material.dart';

import '../shell/ag_artifact_card.dart';

/// Collapsible JSON tree viewer.
///
/// Agent props:
/// ```json
/// {
///   "title": "API response",
///   "data": { "status": "ok", "count": 3, "items": [1, 2, 3] },
///   "expanded": true
/// }
/// ```
/// [data] can be any JSON-serialisable value (map, list, string, num, bool, null).
/// [expanded] controls whether object/array nodes start open (default true).
class AgJsonViewer extends StatelessWidget {
  const AgJsonViewer({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final title = props['title'] as String? ?? 'JSON';
    final data = props['data'];
    final expanded = props['expanded'] as bool? ?? true;

    return AgArtifactCard(
      title: title,
      type: 'JSON',
      icon: Icons.data_object_rounded,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _JsonNode(value: data, expanded: expanded, depth: 0),
      ),
    );
  }
}

// ─── recursive node ──────────────────────────────────────────────────────────

class _JsonNode extends StatefulWidget {
  const _JsonNode({
    super.key,
    required this.value,
    required this.expanded,
    required this.depth,
    this.keyName,
  });

  final dynamic value;
  final bool expanded;
  final int depth;
  final String? keyName;

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.expanded;
  }

  bool get _isComplex =>
      widget.value is Map || widget.value is List;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_isComplex) {
      return _ScalarRow(
        keyName: widget.keyName,
        value: widget.value,
        depth: widget.depth,
        cs: cs,
      );
    }

    final isMap = widget.value is Map;
    final children = isMap
        ? (widget.value as Map).entries.map((e) => MapEntry(e.key.toString(), e.value)).toList()
        : null;
    final listItems = isMap ? null : (widget.value as List);

    final count = isMap ? children!.length : listItems!.length;
    final bracket = isMap ? ('{', '}') : ('[', ']');

    final header = GestureDetector(
      onTap: () => setState(() => _open = !_open),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(left: widget.depth * 14.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _open ? Icons.arrow_drop_down : Icons.arrow_right,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
            if (widget.keyName != null) ...[
              Text(
                '"${widget.keyName}": ',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: cs.primary.withValues(alpha: 0.85),
                ),
              ),
            ],
            Text(
              _open ? bracket.$1 : '${bracket.$1}…${bracket.$2} ($count)',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );

    if (!_open) return header;

    final innerWidgets = isMap
        ? children!.map((e) => _JsonNode(
              key: ValueKey(e.key),
              value: e.value,
              keyName: e.key,
              expanded: widget.expanded,
              depth: widget.depth + 1,
            ))
        : listItems!.asMap().entries.map((e) => _JsonNode(
              key: ValueKey(e.key),
              value: e.value,
              keyName: e.key.toString(),
              expanded: widget.expanded,
              depth: widget.depth + 1,
            ));

    final closing = Padding(
      padding: EdgeInsets.only(left: widget.depth * 14.0 + 16),
      child: Text(
        bracket.$2,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        ...innerWidgets,
        closing,
      ],
    );
  }
}

class _ScalarRow extends StatelessWidget {
  const _ScalarRow({
    required this.value,
    required this.depth,
    required this.cs,
    this.keyName,
  });

  final dynamic value;
  final int depth;
  final ColorScheme cs;
  final String? keyName;

  Color _valueColor() {
    if (value == null) return cs.onSurface.withValues(alpha: 0.4);
    if (value is bool) return const Color(0xFF8b5cf6);
    if (value is num) return const Color(0xFF10b981);
    return const Color(0xFFf59e0b); // string
  }

  String _valueText() {
    if (value == null) return 'null';
    if (value is String) return '"$value"';
    return jsonEncode(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0 + 16, top: 1, bottom: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (keyName != null) ...[
            Text(
              '"$keyName": ',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: cs.primary.withValues(alpha: 0.85),
              ),
            ),
          ],
          Text(
            _valueText(),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: _valueColor(),
            ),
          ),
        ],
      ),
    );
  }
}
