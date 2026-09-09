# Changelog

## Unreleased

- **Fix**: reasoning/thinking events now use the AG-UI spec's own names
  (`THINKING_START`/`THINKING_END`/`THINKING_TEXT_MESSAGE_START`/`CONTENT`/`END`) instead of
  this package's earlier non-spec `REASONING_*` names, so a spec-compliant backend's reasoning
  stream parses correctly. The old wire names and class names (`ReasoningStartEvent`, etc.) still
  work — they're deprecated typedef aliases for the renamed classes — but should be migrated off
  before the next major version.
- **Docs**: `ACTIVITY_SNAPSHOT`/`ACTIVITY_DELTA` are now clearly marked as Agentivity-platform
  extensions, not part of the official AG-UI spec — both event classes implement the new
  `AgentivityExtensionEvent` marker so consumers can distinguish spec events from platform
  extensions programmatically.
- Package relocated into the `agentivity_sdk_flutter` monorepo (git history preserved via
  `git subtree`); this standalone repository will be retired once the SDK is fully consolidated.
- **New**: `InputAudioContentPart`/`OutputAudioContentPart` added to `MessageContentPart` — audio
  now rides the same content-parts array as text/images (`buildAgUiMessage`), mirroring OpenAI's
  `input_audio` shape. Protocol-completeness addition only; no sender/receiver feature wired to
  them yet.

## 0.3.12 - 2026-05-23

**Release 0.3.12**

- 

---


## 0.3.11 - 2026-05-23

**Release 0.3.11**

- 

---


## 0.3.10 - 2026-05-23

**Release 0.3.10**

- 

---


## 0.3.9 - 2026-05-23

**Release 0.3.9**

- 

---


## 0.3.8

**Improved theming.**

- Improve the theming to make it more application to the whole application.

## 0.3.6

**Clean versioning release — correct tag/pubspec alignment.**

- Re-tagged release to ensure the published version on pub.dev matches the Git tag and pubspec version.
- No functional changes since 0.3.5.

---

## 0.3.5

**Fix builder signature in examples; publish pipeline hardening.**

- Fixed `(props) =>` → `(_, props) =>` builder signatures in `example_agentivity`, `example_shopping`, `example_travel` to match `AgUiComponentBuilder` v0.3.x API.
- Added `dev_dependencies` (`flutter_test`, `flutter_lints`) to all example packages.
- Renamed top-level `docs/` → `doc/` to follow pub.dev layout conventions.
- CI: replaced reusable `dart-lang/setup-dart` publish workflow with an explicit pipeline including version/tag validation and `PUB_ENVIRONMENT: github-actions` for OIDC.

---

## 0.3.0

**Breaking: `AgUiComponentBuilder` now receives `BuildContext`.**

- `AgUiComponentBuilder` signature changed from `Widget Function(Map<String, dynamic>)` to `Widget Function(BuildContext, Map<String, dynamic>)`.
  Migration: add `_` (or `context`) as first parameter to all builder lambdas.
- `AgUiWidgetRegistry` updated accordingly.
- Added `AgUiChatTheme`, `AgUiHilTheme`, `AgUiAssistantTheme` theme extensions.
- Chat controller: `loadThreads`, `setSearchQuery`, `openThread`, `sendMessage`, `clearError`.
- HIL controller: `loadPending`, `submitResponse`.
- 187 unit tests passing.

---

## 0.2.0

**Generative UI, protocol alignment, state sync, and frontend tools.**

### New capabilities

- **Generative UI** — `AgUiGenerativeController` processes `Stream<AgUiEvent>` and maintains a sealed `AgUiGenerativeItem` list (`AgUiTextItem`, `AgUiReasoningItem`, `AgUiComponentItem`, `AgUiToolCallItem`). `AgUiGenerativeView` renders it reactively with streaming indicators, collapsible reasoning blocks, and tool-call status cards.
- **Widget registry** — `AgUiWidgetRegistry` maps component names to Flutter widget builders. The agent calls a tool whose name matches a registered component → the controller seamlessly replaces the placeholder with the live widget. Also supported via `CUSTOM` events with `name == 'render'`.
- **Frontend tools** — `AgUiFrontendToolRegistry` / `AgUiFrontendTool` let the agent call client-side code (no backend round-trip). Results are shown inline. Use `toApiDescriptions()` to include frontend tools in the agent's tool list.
- **State sync** — `AgUiStateController` applies `STATE_SNAPSHOT` and `STATE_DELTA` (RFC 6902 JSON Patch: add, remove, replace, move, copy) to a reactive state map. `AgUiStateBuilder` provides a `ListenableBuilder` wrapper.

### Protocol alignment (breaking if you used internal names)

- `ToolCallStartEvent`: JSON key changed from `toolName` → `toolCallName` (legacy `toolName` still read as fallback).
- `ToolCallArgsDeltaEvent`: now handles both spec name `TOOL_CALL_ARGS` and legacy `TOOL_CALL_ARGS_DELTA`.
- `ToolCallResultEvent`: field renamed `result` → `content` (legacy `result` read as fallback); `messageId` is now a required `String`.
- `RunStartedEvent`: added `threadId`, `parentRunId`.
- `RunFinishedEvent`: added `threadId`, `outcome` (`AgUiSuccessOutcome` or `AgUiInterruptOutcome` with `List<AgUiInterrupt>`). `isInterrupted` convenience getter.
- Added event types: `TextMessageChunkEvent`, `ToolCallChunkEvent`, `ReasoningMessageStartEvent`, `ReasoningMessageContentEvent`, `ReasoningMessageEndEvent`, `ReasoningStartEvent`, `ReasoningEndEvent`, `ActivitySnapshotEvent`, `ActivityDeltaEvent`, `RawEvent`.
- `StateDeltaEvent.delta` is now typed `List<dynamic>` (RFC 6902 patch array).

### Tests

- 150 unit tests covering protocol parsing, JSON Patch operations (including `~0`/`~1` escaping and `-` array append), generative controller event handling, and controller notification behaviour.

---

## 0.1.0

Initial release.

- **AG-UI protocol** — sealed `AgUiEvent` hierarchy covering all standard event types (run lifecycle, text messages, tool calls, state, custom). Ready-made `agUiEventParser` for use with `AgUiSseChannel`.
- **SSE channel** — `AgUiSseChannel<T>` with RFC 8895 frame parsing, exponential backoff reconnection, Last-Event-ID tracking, and a 45-second watchdog timer.
- **Abstract provider interfaces** — `IChatProvider`, `IHilProvider`, `IAiAssistantProvider`, `IAgentRunProvider`. Implement against your backend; the package stays backend-agnostic.
- **ChangeNotifier controllers** — `ChatController`, `HilController`, `AiAssistantController`, `AgentRunController`. Drop into any Flutter state management setup (Riverpod, Provider, BLoC, raw `ListenableBuilder`).
- **Flutter widgets** — `AgUiChatPanel`, `AgUiHilForm`, `AgUiAssistantPanel`, `AgUiRunPanel`, `AgUiRunStatusBadge`.
- **ThemeExtension styling** — `AgUiChatTheme`, `AgUiHilTheme`, `AgUiAssistantTheme` integrate with your existing `ThemeData`. Each widget also accepts a per-instance `style` override and builder callbacks for full structural replacement.
