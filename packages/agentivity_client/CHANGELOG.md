# Changelog

## 0.1.0 - Unreleased

- Initial extraction from `agentivity_studio/lib/agentivity_client/`, scoped to read/execute/
  history operations only (entities, generic run lifecycle, HIL, chat, conversations, agentic
  folders, AG-UI bundle/icon discovery). Explicitly excludes workflow/agent/team/credential
  authoring and all diagnostic/inspector/metrics endpoints — those remain Studio-only.
- No Flutter dependency — pure Dart (`dio` + `meta`), usable from any Dart app.
