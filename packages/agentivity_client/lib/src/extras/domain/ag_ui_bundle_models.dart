// ─────────────────────────────────────────────────────────────────────────────
// AG-UI Bundle models (EPIC-0445)
//
// Summary list: GET /api/v1/ag-ui/bundles
// Detail:       GET /api/v1/ag-ui/bundles/{bundleId}
// ─────────────────────────────────────────────────────────────────────────────

class AgUiBundleSummary {
  const AgUiBundleSummary({
    required this.id,
    required this.displayName,
    required this.version,
    this.description,
    required this.widgetCount,
  });

  final String id;
  final String displayName;
  final String version;
  final String? description;
  final int widgetCount;

  factory AgUiBundleSummary.fromJson(Map<String, dynamic> json) {
    return AgUiBundleSummary(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      version: json['version'] as String? ?? '',
      description: json['description'] as String?,
      widgetCount: (json['widgetCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AgUiBundleWidget {
  const AgUiBundleWidget({
    required this.typeKey,
    this.category,
    this.description,
  });

  final String typeKey;
  final String? category;
  final String? description;

  factory AgUiBundleWidget.fromJson(Map<String, dynamic> json) {
    return AgUiBundleWidget(
      typeKey: json['typeKey'] as String? ?? '',
      category: json['category'] as String?,
      description: json['description'] as String?,
    );
  }
}

class AgUiBundleDetail {
  const AgUiBundleDetail({
    required this.id,
    required this.displayName,
    required this.version,
    this.description,
    required this.widgets,
  });

  final String id;
  final String displayName;
  final String version;
  final String? description;
  final List<AgUiBundleWidget> widgets;

  factory AgUiBundleDetail.fromJson(Map<String, dynamic> json) {
    final rawWidgets = json['widgets'];
    final widgets = <AgUiBundleWidget>[];
    if (rawWidgets is List) {
      for (final item in rawWidgets) {
        if (item is Map<String, dynamic>) {
          widgets.add(AgUiBundleWidget.fromJson(item));
        } else if (item is Map) {
          widgets.add(AgUiBundleWidget.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return AgUiBundleDetail(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      version: json['version'] as String? ?? '',
      description: json['description'] as String?,
      widgets: widgets,
    );
  }
}
