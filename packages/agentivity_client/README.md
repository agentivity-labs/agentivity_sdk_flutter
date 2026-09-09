# agentivity_client

Pure-Dart API client for the [Agentivity](https://agentivity.io) platform — build your own app
that talks to an Agentivity backend, without depending on Studio-only management features.

## Scope: read, execute, and watch history — not administer

This client covers everything a third-party application needs to **use** the platform:

- Discover agents, teams, and workflows (`entities`)
- Start and monitor runs — cancel, pause/unpause, resume — for any entity kind (`runs`)
- Respond to human-in-the-loop (HIL) requests
- Chat with an agent over the AG-UI protocol (`chat`)
- Read conversation/execution history (`conversations`)
- Discover AG-UI generative-UI widget bundles (`agUiBundles`) and icon assets (`svgIcons`)
- Manage folders for organizing your own agentic entities (`agenticFolders`)

**Deliberately not included**: creating, editing, or deleting workflows, agents, teams, or
credentials, and any diagnostic/inspector tooling (run inspector, node diagnostics, run metrics).
Those are Agentivity Studio (admin) concerns, not something a consumer application should do —
see [`_prd_docs`](https://agentivity.io) if you're building the Studio itself.

## Get started

```yaml
# pubspec.yaml
dependencies:
  agentivity_client: ^0.1.0
```

```dart
import 'package:agentivity_client/agentivity_client.dart';

final client = AgentivityPlatformClient(baseUrl: 'https://my-backend.example.com');

// Discover agents
final agents = await client.entities.fetchEntities(kind: 'agent');

// Start a run
final run = await client.runs.startExecution(entityId: agents.first.id, input: 'Hello');

// Stream its events
final stream = await client.runs.openEventStream(run.runId);
```

Pair this with [`agentivity_ag_ui`](https://pub.dev/packages/agentivity_ag_ui) (AG-UI protocol
streaming, ready-made chat/forms panels) and
[`agentivity_artifacts`](https://pub.dev/packages/agentivity_artifacts) (renderable generative-UI
widgets) for a complete client application.

## No Flutter dependency

This package is pure Dart — usable from a Flutter app, a command-line tool, or a server-side Dart
process. UI components live in `agentivity_ag_ui`/`agentivity_artifacts`, not here.

## Part of the Agentivity SDK monorepo

This package lives in [`agentivity_sdk_flutter`](https://github.com/agentivity-labs/agentivity_sdk_flutter)
alongside `agentivity_ag_ui` and `agentivity_artifacts`.

## License

MIT © Agentivity
