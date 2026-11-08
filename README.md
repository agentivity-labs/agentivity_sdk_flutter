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

## Keys, and what the instance refuses

An instance that asks to sign in wants a key with every request; one that does not (Community) wants none. Anything outside the
instance (a SaaS, a script, a website, a mobile app) talks to it with an **API key** `agv_…`, made by an administrator in the Studio
under *API keys*. A key is never a person: it belongs to a space, opens only the Solutions you choose there (or every Solution of
the space), and does what its permissions say: **run** them and follow their executions, use the space's **assets** (Data Tables
rows, Knowledge Bases), serve an AI assistant over **MCP**, give tokens to the **users** of your system. It builds nothing: agents, teams and
workflows are made in the Studio.

- **On your server** (a server, a script, a back office): give the key to the client. Keep it there; never put it in an app.

  ```dart
  final client = AgentivityPlatformClient(
    baseUrl: 'https://my-instance.example.com',
    apiKey: const String.fromEnvironment('AGENTIVITY_API_KEY'),
  );
  ```

- **An app in people's hands** (Flutter web, mobile, desktop): anything shipped can be read, so it never holds a key. With a key
  that has the permission *users*, your server asks the instance for the token of each of your users
  (`POST /api/v1/keys/user-tokens`, worth 15 minutes), or for an anonymous visitor of a demo (`POST /api/v1/keys/visitors`), and
  the app speaks for them; each has their own conversations. People of the workspace sign in through the key instead
  (`client.keys.signIn(keyId: …, email: …, password: …)`).

  ```dart
  // Your users: your server gives the token of the user of the app.
  client.setUserToken(token, renew: () => myServer.agentivityToken());
  // A demo: each device keeps the anonymous visitor the demo's server gave it.
  client.keys.visitDemo(() => myServer.agentivityVisitor());
  ```

The key goes as `Authorization: Bearer <key>` (the instance also reads `x-api-key`).

When the instance refuses, every call of the client throws an `ApiException`. The exception's `userMessage` comes from the instance, or
from the SDK when the instance sent only a code. It also carries `code`, `httpStatus`, `kind` (an `ApiFailureKind`: `key`, `forbidden`,
`notFound`, `rateLimited`, `server`, `network`, `other`) and, for a refusal of rights, the `permission` that was needed. A stream the
instance refuses does not reconnect for ever: it stops with `AgUiConnectionStatus.terminated`, and its `connectionStateNotifier` carries
the `refusal`. `isFinal` says whether trying again would get the same answer: every 4xx except 408 and 429.

```dart
try {
  await client.runs.startExecution(entityId: entityId, input: 'Hello');
} on ApiException catch (error) {
  if (error.kind == ApiFailureKind.key) showSignInHelp(error.userMessage);
}
```

| `code` | Status | What it means |
|---|---|---|
| `sign_in_required` | 401 | The instance asks for a key and got none. |
| `invalid_key` | 401 | The key was deleted, renewed, or is mistyped. |
| `key_scope` | 403 | The key's permissions (`run`, `assets`, `mcp`, `users`) do not cover this call. |
| `key_in_page` | 403 | The key was sent from a web page: it stays on your server. |
| `key_solutions` | 403 | With a key, a call it does not open. |
| `key_solution` | 403 | With a key, a Solution it does not open. |
| `permission_denied` | 403 | This is not allowed (`permission` names what was needed). |
| `people_only` | 403 | Only a person signed in to the Studio does this, never a key. |
| `space_not_visible` | 403 | The element is in another space than the key. |
| `edition_feature` | 403 | The edition of the instance does not include this. |
| `edition_limit` | 403 | The edition of the instance allows no more of this. |
| `too_many_starts` | 429 | Too many conversations started from one site: try again in a minute. |

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
