# agentivity_sdk

The Flutter/Dart SDK for building applications against the [Agentivity](https://agentivity.io)
platform: a real-time AG-UI-protocol client, generative-content widgets, and a platform API
client — one package, for building new apps and integrations. Administering the platform
(creating/editing workflows, agents, teams, or credentials) stays inside Agentivity Studio, not
this SDK.

## What's in it

| Area | What it gives you |
| --- | --- |
| **AG-UI protocol** | SSE streaming, event parsing, run controllers, and ready-made chat/forms/assistant panels. |
| **Artifacts** | Renderable widgets for AI-generated content — charts, code blocks, JSON, status cards, and a 6-widget interaction-card family (choice, confirm, date, form, rating, summary). |
| **Platform client** | Pure API access — discover agents/teams/workflows, start/monitor/cancel runs, respond to human-in-the-loop requests, chat, read history. |

Everything is exported from one barrel:

```dart
import 'package:agentivity_sdk/agentivity_sdk.dart';
```

## Get started

```yaml
# pubspec.yaml
dependencies:
  agentivity_sdk: ^0.1.0
```

```dart
import 'package:agentivity_sdk/agentivity_sdk.dart';

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

## Scope: read, execute, and watch history — not administer

The platform client covers everything a third-party application needs to **use** the platform:
discovering entities, starting and monitoring runs (cancel/pause/resume/HIL), chatting over
AG-UI, reading conversation/execution history, and discovering generative-UI widget bundles and
icon assets.

**Deliberately not included**: creating, editing, or deleting workflows, agents, teams, or
credentials, and any diagnostic/inspector tooling (run inspector, node diagnostics, run metrics).
Those are Agentivity Studio (admin) concerns.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

A single Flutter package — no monorepo tooling required.

## License

MIT © Agentivity
