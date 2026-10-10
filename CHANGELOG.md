# Changelog

## 0.1.0 - Unreleased

- **`AgUiTemplateGraph` and `resolveRenderable`.** Draw a team, a workflow or an agent from JSON alone (a Template file, the
  marketplace's `/root` payload, a catalog wrapper or a bare entity) — no run, no chat. Optional `autoplay`, `interactive`
  (off by default, so the picture scrolls with the page). `AgUiTeamGraph` and `AgUiWorkflowGraph` no longer require a
  `controller` and gain `statuses` and `interactive`; `AgUiWorkflowGraph` gains `camera: AgUiWorkflowCamera.fit`. A workflow
  with a single node is drawn at its normal size.
- **`camera` on `AgUiTemplateGraph`.** `AgUiWorkflowCamera.follow` opens a workflow (or the graph inside an agent) on its start node at
  a readable scale and, with `autoplay`, glides from one active node to the next (back to the start when the loop begins again); the
  widget fills the size its parent gives it, or is 16:9 (240 high at least) when the height is unbounded, and the drawing is clipped by
  that frame only. `fit` (the default) keeps the whole diagram in view, as before. Still picture when the platform asks for reduced
  motion. A team is not affected.
- **Merged into a single package.** `agentivity_ag_ui`, `agentivity_artifacts`, and
  `agentivity_client` are now one published package, `agentivity_sdk` — one dependency, one
  version, one barrel import (`package:agentivity_sdk/agentivity_sdk.dart`). The three areas
  live side by side under `lib/src/{ag_ui,artifacts,client}/`. Git history for each area is
  preserved through the earlier per-package repos and the brief `agentivity_sdk_flutter`
  monorepo stage.
- Dropped the old standalone demo example apps (`example`, `example_agentivity`,
  `example_shopping`, `example_support`, `example_travel`) — a real showcase app (built against
  a live workflow/agent/team) is planned as a follow-up, not a set of isolated protocol demos.
- **AG-UI protocol fixes** (carried over from the `agentivity_ag_ui` merge): reasoning/thinking
  events renamed to the spec's own `THINKING_*` names (old `REASONING_*` names kept as deprecated
  aliases); `ACTIVITY_SNAPSHOT`/`ACTIVITY_DELTA` marked as Agentivity-platform extensions via the
  `AgentivityExtensionEvent` marker, not part of the official spec.
- **New**: `AgUiChatDiscussion` — composes `AgUiChatInput` + the chat message list into one
  ready-to-drop-in widget (previously every consumer hand-wired the two separately).
- **New**: `InputAudioContentPart`/`OutputAudioContentPart` on `MessageContentPart` — audio rides
  the same content-parts array as text/images, mirroring OpenAI's `input_audio` shape.
  Protocol-completeness addition only; no sender/receiver feature wired to them yet.
- **New**: `agentivity_client` surface (from the `agentivity_client` merge) — entities, generic
  run lifecycle, HIL, chat, conversations, agentic folders, AG-UI bundle/icon discovery. Scoped to
  read/execute/history only: no workflow/agent/team/credential authoring, no diagnostic/inspector/
  metrics endpoints — those remain Studio-only.
- Removed two duplicate/legacy chat DTO types (`ChatMessage`, `ChatMessageRole` from the old
  client-side model) that collided by name with the AG-UI panel's own richer versions and were
  unused; the client's active thread/message DTOs are `InteractionThread`/`ThreadMessage`/
  `InteractionThreadDetail` (renamed from `ChatThreadDetail` to resolve the same collision).
- Docs: `agentivity_artifacts`' widget count corrected (14→20, the interaction card family was
  shipped but undocumented) and a `AgUiChatDiscussion.widgetRegistry` wiring example added.
