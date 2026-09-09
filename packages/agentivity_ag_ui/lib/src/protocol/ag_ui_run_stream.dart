// This file is intentionally kept for backwards compatibility.
// The types it previously defined have been replaced:
//
//   AgUiRunStream     -> PlatformStream      (protocol/platform_stream.dart)
//   AgUiRunEvent      -> removed (split into AgUiEvent + PlatformSignal)
//   AgUiProtocolEvent -> removed (AgUiEvent is emitted directly on agUiEvents)
//   AgUiSyncSignal    -> AgentivitySyncSignal (connectors/agentivity_signals.dart)
//
// All new code should import platform_stream.dart directly.
export 'platform_stream.dart';
