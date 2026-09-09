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

## Used together

The three packages are designed to compose: `agentivity_client` talks to the backend,
`agentivity_ag_ui` streams and renders the conversation, `agentivity_artifacts` renders any
generative-UI content the agent sends back.

```dart
import 'package:agentivity_client/agentivity_client.dart';
import 'package:agentivity_ag_ui/agentivity_ag_ui.dart';
import 'package:agentivity_artifacts/agentivity_artifacts.dart';

final client = AgentivityPlatformClient(baseUrl: 'https://my-backend.example.com');

// Discover an agent to talk to.
final agents = await client.entities.fetchEntities(kind: 'agent');

// Render a full chat experience for it — composer, message list, and any
// generative-UI content (charts, cards, forms) the agent sends back — as one widget.
AgUiChatDiscussion(
  controller: ChatController(chatContextApi: client.chat, entityId: agents.first.id),
  widgetRegistry: AgArtifactsBundle.registry(),
);
```

`agentivity_client` deliberately stops at read/execute/history — it cannot create or edit
workflows, agents, teams, or credentials. Building an admin/authoring surface (like Agentivity
Studio itself) is a separate, out-of-scope concern for this SDK.
