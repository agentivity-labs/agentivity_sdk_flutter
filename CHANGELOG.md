## 0.1.1 - 2026-05-23

**Release 0.1.1**

- 

---

## 0.1.0

* Initial public release.
* 14 artifact widgets: `AgBarChart`, `AgLineChart`, `AgPieChart`, `AgAreaChart`, `AgRadarChart`, `AgMetricCard`, `AgStatGrid`, `AgKeyValue`, `AgCodeBlock`, `AgJsonViewer`, `AgStatusCard`, `AgTimeline`, `AgLatex`, `AgSvg`.
* 11 built-in themes: Agentivity, Noir, Ember, Candy, Glacier, Paper, Brutalist, Aurora, Neon, Sakura, Ocean.
* `AgArtifactsBundle.registry()` integrates the full widget catalogue into any `agentivity_ag_ui` generative-UI pipeline in one call.
* Standalone mode: all widgets work without `agentivity_ag_ui` — pass a plain `Map<String, dynamic>` via the `props` argument.
* `AgArtifactsTheme` / `AgArtifactsThemeData` ThemeExtension drives colours, chart palette, card radius, and code font across every widget.
* Showcase example app with 7 animated demos (Financial, Ops, E-commerce, Code Review, Scientific, Architecture, Agent Log).
