# Agentivity SDK (Flutter)

The Flutter/Dart SDK for building applications against the Agentivity platform: a real-time,
AG-UI-protocol client, generative-content widgets, and a platform API client — for building new
apps and integrations, not for administering the platform (creating/editing workflows, agents,
teams, or credentials stays inside the Studio app).

## Packages

| Package | Purpose |
| --- | --- |
| [`agentivity_ag_ui`](packages/agentivity_ag_ui) | AG-UI protocol client — SSE streaming, chat/forms panels, run controllers. |
| [`agentivity_artifacts`](packages/agentivity_artifacts) | Renderable widgets for AI-generated content (charts, code blocks, interaction cards, ...). |
| [`agentivity_client`](packages/agentivity_client) | Platform API client — read, execute, and watch history for agents/teams/workflows/chat. |

## Getting started

This is a [melos](https://melos.invertase.dev/) monorepo.

```bash
dart pub global activate melos
melos bootstrap
```

See each package's own README for usage.
