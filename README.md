# agentivity_artifacts

[![pub.dev](https://img.shields.io/pub/v/agentivity_artifacts.svg)](https://pub.dev/packages/agentivity_artifacts)
[![CI](https://github.com/agentivity-labs/agentivity_artifacts/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/agentivity-labs/agentivity_artifacts/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Live demo](https://img.shields.io/badge/Live%20demo-labs.agentivity.io-6366f1)](https://labs.agentivity.io/agentivity_artifacts/example/)

**14 Flutter widgets for rendering AI agent artifacts — charts, metrics, code, JSON, math, SVG and status cards.**

Drop them into any Flutter app standalone, or wire them into a live [AG-UI](https://github.com/ag-ui-protocol/ag-ui) agent stream so your agent decides at runtime what to render and with what data.

**[🔬 Live showcase →](https://labs.agentivity.io/agentivity_artifacts/example/)**

---

## What it renders

| Group | Widget | AG-UI type key | What it shows |
|---|---|---|---|
| **Charts** | `AgBarChart` | `BarChart` | Grouped / stacked bar chart |
| | `AgLineChart` | `LineChart` | Multi-series line chart |
| | `AgPieChart` | `PieChart` | Pie / donut chart with legend |
| | `AgAreaChart` | `AreaChart` | Filled area chart |
| | `AgRadarChart` | `RadarChart` | Spider / radar chart |
| **Data** | `AgMetricCard` | `MetricCard` | Single KPI with delta and trend |
| | `AgStatGrid` | `StatGrid` | Responsive grid of KPI cards |
| | `AgKeyValue` | `KeyValue` | Key–value table with highlight rows |
| **Code** | `AgCodeBlock` | `CodeBlock` | Syntax-highlighted code with copy |
| | `AgJsonViewer` | `JsonViewer` | Collapsible JSON tree |
| **Status** | `AgStatusCard` | `StatusCard` | Success / warning / error / info card |
| | `AgTimeline` | `Timeline` | Step timeline with status icons |
| **Math** | `AgLatex` | `Latex` | LaTeX math via `flutter_math_fork` |
| **SVG** | `AgSvg` | `Svg` | Inline SVG diagram |

Every widget accepts a plain `Map<String, dynamic> props` — no custom data classes required.

---

## Get started

```yaml
# pubspec.yaml
dependencies:
  agentivity_artifacts: ^0.1.0
```

### Standalone (no backend needed)

```dart
import 'package:agentivity_artifacts/agentivity_artifacts.dart';

// A KPI grid — four metrics in one row
AgStatGrid(props: {
  'columns': 4,
  'metrics': [
    {'title': 'Revenue',  'value': '\$12.4 k', 'delta': '+8 %',  'trend': 'up'},
    {'title': 'Orders',   'value': '348',       'delta': '+12 %', 'trend': 'up'},
    {'title': 'Refunds',  'value': '4',         'delta': '−2',    'trend': 'down'},
    {'title': 'Margin',   'value': '34 %',      'delta': 'flat',  'trend': 'flat'},
  ],
})

// A syntax-highlighted code block
AgCodeBlock(props: {
  'title': 'main.dart',
  'language': 'dart',
  'code': 'void main() => runApp(const MyApp());',
})

// A LaTeX formula
AgLatex(props: {
  'title': 'Euler's identity',
  'tex': r'e^{i\pi} + 1 = 0',
  'display': true,
})
```

### With agentivity_ag_ui (live agent stream)

Register the full widget catalogue in one call and let your agent decide what to render:

```dart
import 'package:agentivity_ag_ui/agentivity_ag_ui.dart';
import 'package:agentivity_artifacts/agentivity_artifacts.dart';

AgUiGenerativeView(
  controller: AgUiGenerativeController(
    events: channel.events,
    widgetRegistry: AgArtifactsBundle.registry(
      // Add your own custom widgets alongside the built-ins
      extra: {'MyCard': (context, props) => MyCard(props: props)},
    ),
  ),
  registry: AgArtifactsBundle.registry(),
)
```

Your agent then emits a `CUSTOM ag-ui:render` event:

```json
{
  "type": "CUSTOM",
  "name": "ag-ui:render",
  "value": {
    "type": "BarChart",
    "props": {
      "title": "Weekly sales",
      "labels": ["Mon","Tue","Wed","Thu","Fri"],
      "datasets": [{"label": "Units", "data": [12, 18, 9, 24, 15]}]
    }
  }
}
```

Flutter receives it and renders `AgBarChart` — no redeploy, no hardcoded routes.

---

## Theming

All widgets inherit from `ThemeData` automatically. Go further with the built-in `AgArtifactsTheme` extension:

```dart
MaterialApp(
  theme: ThemeData(
    extensions: [
      AgArtifactsThemeData(
        chartPalette: ['#6366f1', '#10b981', '#f59e0b', '#ef4444'],
        cardRadius: 10,
        codeFontFamily: 'JetBrains Mono',
      ),
    ],
  ),
)
```

### 11 ready-made presets

Switch theme with a single string — great for showcases and demos:

```dart
MaterialApp(
  theme: AgArtifactsThemes.themeDataFor('Noir'),   // or any name below
)
```

| Name | Mood | Brightness |
|---|---|---|
| `Agentivity` | Indigo / default | ☀️ Light |
| `Noir` | Near-black, crisp whites | 🌑 Dark |
| `Ember` | Amber + charcoal | 🌑 Dark |
| `Candy` | Pink + sky | ☀️ Light |
| `Glacier` | Ice blue + slate | ☀️ Light |
| `Paper` | Off-white, serif feel | ☀️ Light |
| `Brutalist` | Stark black + yellow | ☀️ Light |
| `Aurora` | Teal + violet | 🌑 Dark |
| `Neon` | Electric green + black | 🌑 Dark |
| `Sakura` | Blush pink | ☀️ Light |
| `Ocean` | Deep blue | 🌑 Dark |

---

## Showcase app

The `example/` folder contains a full-featured showcase with 7 animated demos. Each demo streams its sections in one by one, simulating a live agent response:

| Demo | Theme suggestion | What it shows |
|---|---|---|
| Financial Intelligence | Noir | KPIs, candlestick-style line chart, bar + pie, radar portfolio risk, key-value |
| Ops Dashboard | Ember | Metrics, status cards, timeline, bar chart, JSON payload |
| E-commerce Burst | Candy | GMV KPIs, revenue area chart, bar chart, fulfilment timeline |
| AI Code Review | Glacier | Diff code blocks, test stats, PR timeline, key-value |
| Scientific Report | Paper | LaTeX formulas, trigonometric line chart, Python code, Black-Scholes params |
| Architecture | Brutalist | SVG diagram, TypeScript + YAML code, key-value, milestone timeline |
| Agent Activity Log | Aurora | Run metrics, status cards, execution timeline, JSON tool call, generated code |

```bash
cd example && flutter run -d chrome
```

---

## Widget props reference

### Charts — shared props

| Prop | Type | Description |
|---|---|---|
| `title` | `String?` | Card header |
| `labels` | `List<String>` | X-axis / category labels |
| `datasets` | `List<Map>` | Each map: `label`, `data: List<num>`, optional `color` |
| `height` | `num?` | Override chart area height (px) |

### `AgStatGrid`

| Prop | Type | Description |
|---|---|---|
| `metrics` | `List<Map>` | Each map: `title`, `value`, `delta?`, `trend?` (`up`/`down`/`flat`), `subtitle?` |
| `columns` | `int?` | Force column count (responsive fallback applies on narrow screens) |

### `AgCodeBlock`

| Prop | Type | Description |
|---|---|---|
| `code` | `String` | Source code to display |
| `language` | `String?` | Highlight language (`dart`, `python`, `typescript`, `yaml`, …) |
| `title` | `String?` | Card header |
| `maxLines` | `int?` | Scrollable viewport height (lines) |

### `AgTimeline`

| Prop | Type | Description |
|---|---|---|
| `events` | `List<Map>` | Each map: `label`, `time?`, `status` (`success`/`running`/`pending`/`warning`/`error`), `note?` |
| `title` | `String?` | Card header |

### `AgLatex`

| Prop | Type | Description |
|---|---|---|
| `tex` | `String` | LaTeX source (raw string recommended) |
| `display` | `bool?` | `true` = display (block) mode, `false` = inline |
| `title` | `String?` | Card header |

### `AgStatusCard`

| Prop | Type | Description |
|---|---|---|
| `title` | `String` | Card title |
| `status` | `String` | `success` / `warning` / `error` / `info` |
| `message` | `String?` | Body text |
| `details` | `List<String>?` | Bullet points below the message |

---

## Agentivity Labs

**[labs.agentivity.io](https://labs.agentivity.io)** is our open research and engineering lab — where we explore what it means to build production-grade interfaces for AI agents.

Our mission is to make agentic AI accessible to everyone — from individuals exploring what agents can do, to teams running complex workflows, to large organisations embedding agents into their core operations. Not just accessible to engineers: accessible to anyone who wants to work alongside AI agents, understand what they are doing, and stay in control.

We believe the bottleneck is not model capability — it is the lack of a mature ecosystem around it. Agentivity's core product is a visual platform for designing, composing, and operating agentic systems: teams of agents that are modifiable, reusable, and deployable at any scale. The open-source work published here is part of that ecosystem — the building blocks we open up so the broader community can build on the same foundation.

**What we publish:**

- **Open-source libraries** — Flutter SDKs, protocol implementations, and UI toolkits for agentic applications. [`agentivity_ag_ui`](https://pub.dev/packages/agentivity_ag_ui) handles the AG-UI protocol; this package handles the artifact widgets.
- **Live demos** — fully working, themed examples you can browse directly in your browser, built on the same packages you install from pub.dev.
- **Technical articles** — walkthroughs, architecture decisions, and patterns we encounter building real agentic products.

---

## Contributing

Issues and PRs are welcome. For major changes, open an issue first to align on direction.

Built and maintained by [Agentivity](https://agentivity.io) — the platform for AI agent orchestration and monitoring.

---

## License

[MIT](LICENSE) © Agentivity
