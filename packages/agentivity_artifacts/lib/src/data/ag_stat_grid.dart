import 'package:flutter/material.dart';

import 'ag_metric_card.dart';

/// Grid of KPI metric cards.
///
/// Agent props:
/// ```json
/// {
///   "columns": 4,
///   "metrics": [
///     { "title": "ARR",   "value": "€ 1.2M", "delta": "+18%", "trend": "up" },
///     { "title": "MRR",   "value": "€ 98k",  "delta": "+5%",  "trend": "up" },
///     { "title": "Churn", "value": "2.1%",   "delta": "-0.3%","trend": "down" },
///     { "title": "NPS",   "value": "72",     "delta": "+4",   "trend": "up" }
///   ]
/// }
/// ```
///
/// [columns] controls how many cards appear per row:
/// - Omit (or `null`): auto — 1 column below 360 px, 2 otherwise.
/// - `4` (or any value): force that many columns, with responsive fallback
///   (→ 2 on narrow, → 1 on very narrow screens).
class AgStatGrid extends StatelessWidget {
  const AgStatGrid({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final metrics = (props['metrics'] as List?) ?? [];
    final forcedCols = (props['columns'] as num?)?.toInt();

    return LayoutBuilder(
      builder: (context, constraints) {
        final int cols;
        if (forcedCols != null && forcedCols > 0) {
          // Responsive clamp for forced columns
          if (constraints.maxWidth < 400) {
            cols = 1;
          } else if (constraints.maxWidth < 700) {
            cols = forcedCols.clamp(1, 2);
          } else {
            cols = forcedCols.clamp(1, metrics.length);
          }
        } else {
          cols = constraints.maxWidth < 360 ? 1 : 2;
        }

        if (cols == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                AgMetricCard(props: metrics[i] as Map<String, dynamic>),
              ],
            ],
          );
        }

        // Multi-column: IntrinsicHeight lets each row match its tallest card.
        final rows = <Widget>[];
        for (var i = 0; i < metrics.length; i += cols) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));

          final rowChildren = <Widget>[];
          for (var j = 0; j < cols; j++) {
            if (rowChildren.isNotEmpty) rowChildren.add(const SizedBox(width: 8));
            final idx = i + j;
            rowChildren.add(
              Expanded(
                child: idx < metrics.length
                    ? AgMetricCard(props: metrics[idx] as Map<String, dynamic>)
                    : const SizedBox(),
              ),
            );
          }

          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowChildren,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
