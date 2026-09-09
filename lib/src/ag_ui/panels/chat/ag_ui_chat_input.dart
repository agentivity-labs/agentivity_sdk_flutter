import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../theme/ag_theme_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Attachment model
// ─────────────────────────────────────────────────────────────────────────────

/// A pending attachment held in [AgUiChatInput] before the user sends.
sealed class AgUiInputAttachment {
  const AgUiInputAttachment({this.name});
  final String? name;
}

/// A file from the OS picker or a drag-and-drop operation.
final class AgUiFileAttachment extends AgUiInputAttachment {
  const AgUiFileAttachment({required this.path, super.name, this.mimeType});
  final String path;
  final String? mimeType;
}

/// Raw image bytes from the clipboard (Ctrl+V).
final class AgUiImageBytesAttachment extends AgUiInputAttachment {
  const AgUiImageBytesAttachment({required this.bytes, super.name, this.mimeType});
  final Uint8List bytes;
  final String? mimeType;
}

// ─────────────────────────────────────────────────────────────────────────────
// AgUiChatInput
// ─────────────────────────────────────────────────────────────────────────────

/// A configurable agentic chat input bar — VS Code-style.
///
/// The text field, attachment chips, and the toolbar live **inside** a single
/// rounded container whose border uses the theme accent color and pulses
/// subtly while [loading] is true.
///
/// Layout (inside the container):
/// ```
/// ┌─────────────────────────────────────────────────────┐  ← accent border
/// │ [chips if any]                                      │
/// │ TextField (no own border, expands)                  │
/// ├─────────────────────────────────────────────────────┤  ← hairline divider
/// │ [+] [leadingActions] [mic]    [trailingActions] [↑] │  ← toolbar
/// └─────────────────────────────────────────────────────┘
/// ```
///
/// [actionBar] is rendered **above** the container (e.g. a SwitchListTile).
///
/// ## Basic usage
/// ```dart
/// AgUiChatInput(
///   onSend: (text, attachments) { ... },
///   hint: 'Type a message…',
/// )
/// ```
class AgUiChatInput extends StatefulWidget {
  const AgUiChatInput({
    required this.onSend,
    super.key,
    this.controller,
    this.hint = 'Type a message…',
    this.hilHint = 'Type your response…',
    this.minLines = 1,
    this.maxLines = 6,
    this.enabled = true,
    this.loading = false,
    this.isHil = false,
    this.enableVoice = true,
    this.enableAttachments = true,
    this.acceptedExtensions,
    this.actionBar,
    this.leadingActions,
    this.trailingActions,
    this.loadingOverlay,
  });

  /// Called when the user submits. [text] is the trimmed content; [attachments]
  /// is the list of pending file/image attachments (cleared after callback).
  final void Function(String text, List<AgUiInputAttachment> attachments) onSend;

  /// External controller. If null, the widget manages its own controller.
  final TextEditingController? controller;

  /// Placeholder shown in normal mode.
  final String hint;

  /// Placeholder shown when [isHil] is `true`.
  final String hilHint;

  final int minLines;
  final int maxLines;

  /// When `false`, the text field and all buttons are disabled.
  final bool enabled;

  /// When `true`, the send button shows a spinner and the border pulses.
  final bool loading;

  /// Switches the input into HIL (human-in-the-loop) mode:
  /// uses [hilHint] and applies a tertiary-tinted border and fill.
  final bool isHil;

  /// Shows a microphone button and enables speech-to-text transcription.
  final bool enableVoice;

  /// Shows the [+] attachment button and accepts drag-and-drop.
  final bool enableAttachments;

  /// File extensions accepted by the picker (e.g. `['pdf','png']`).
  /// `null` means all files accepted.
  final List<String>? acceptedExtensions;

  /// Full-width widget rendered **above** the container.
  /// Typical use: a `SwitchListTile` for enabling HIL mode.
  final Widget? actionBar;

  /// Widgets in the bottom-left toolbar (after the [+] and mic buttons).
  final List<Widget>? leadingActions;

  /// Widgets in the bottom-right toolbar (before the send button).
  final List<Widget>? trailingActions;

  /// Optional widget overlaid (full-size, pointer-ignored) on top of the
  /// border container when [loading] is true. Typically an animated border
  /// painter defined by the host app (e.g. a rotating sweep gradient).
  final Widget? loadingOverlay;

  @override
  State<AgUiChatInput> createState() => _AgUiChatInputState();
}

class _AgUiChatInputState extends State<AgUiChatInput> with SingleTickerProviderStateMixin {
  late TextEditingController _ctrl;
  bool _ownsController = false;
  final FocusNode _focusNode = FocusNode();

  final List<AgUiInputAttachment> _attachments = [];
  bool _isDragOver = false;

  // Voice
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  bool _voiceOverlayOpen = false;
  BuildContext? _voiceOverlayContext;
  String? _voiceSessionBaseText;
  final ValueNotifier<String> _liveTranscript = ValueNotifier<String>('');
  static const int _waveformBarCount = 24;
  final ValueNotifier<List<double>> _waveform = ValueNotifier<List<double>>(List<double>.filled(_waveformBarCount, 0.0));
  Stopwatch? _recordingStopwatch;
  Timer? _recordingTimer;
  final ValueNotifier<Duration> _recordingElapsed = ValueNotifier<Duration>(Duration.zero);

  // speech_to_text's onSoundLevelChange isn't implemented by every platform backend
  // (the Windows and web implementations never call it at all — confirmed against
  // their source), so real waveform amplitude comes from a separate `record` session
  // (dBFS via onAmplitudeChanged, supported on every platform this app targets,
  // including Windows and web) running alongside speech_to_text purely for metering —
  // its audio bytes are discarded, only the amplitude stream is used.
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<List<int>>? _recorderAudioSub;
  Timer? _amplitudeWatchdog;
  bool _receivedRealAmplitude = false;

  // If `record` itself can't provide amplitude either (e.g. mic permission denied),
  // fall back to a synthetic "breathing" waveform so there's still visible
  // confirmation that recording is active, rather than a dead flat line.
  Timer? _syntheticWaveformTimer;
  double _syntheticLevel = 0.3;
  final math.Random _syntheticRandom = math.Random();

  // Animations
  // _pulseCtrl: breathing for voice mic (reverse repeat, 1 s)
  late AnimationController _pulseCtrl;
  late Animation<double> _voicePulseAnim; // 0.5→1.0 mic icon opacity

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ctrl = TextEditingController();
      _ownsController = true;
    } else {
      _ctrl = widget.controller!;
    }

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _voicePulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _focusNode.addListener(() => setState(() {}));

    if (widget.enableVoice) _initStt();
  }

  @override
  void didUpdateWidget(AgUiChatInput old) {
    super.didUpdateWidget(old);
    if (widget.controller != null && old.controller != widget.controller) {
      if (_ownsController) {
        _ctrl.dispose();
        _ownsController = false;
      }
      _ctrl = widget.controller!;
    }
    if (widget.enableVoice && !old.enableVoice) _initStt();
  }

  @override
  void dispose() {
    if (_ownsController) _ctrl.dispose();
    _focusNode.dispose();
    _pulseCtrl.dispose();
    _liveTranscript.dispose();
    _waveform.dispose();
    _recordingElapsed.dispose();
    _recordingTimer?.cancel();
    _syntheticWaveformTimer?.cancel();
    _amplitudeWatchdog?.cancel();
    _amplitudeSub?.cancel();
    _recorderAudioSub?.cancel();
    _recorder.dispose();
    if (_isListening) _stt.stop();
    super.dispose();
  }

  // ── Speech-to-text ──────────────────────────────────────────────────────────

  Future<void> _initStt() async {
    bool available;
    try {
      available = await _stt.initialize(
        onError: (error) {
          developer.log('speech_to_text error: $error', name: 'AgUiChatInput');
          if (mounted) setState(() => _isListening = false);
        },
        onStatus: (status) => developer.log('speech_to_text status: $status', name: 'AgUiChatInput'),
      );
    } catch (error, stackTrace) {
      developer.log('speech_to_text initialize() threw', name: 'AgUiChatInput', error: error, stackTrace: stackTrace);
      available = false;
    }
    if (!available) {
      developer.log(
        'speech_to_text unavailable on this platform/browser — the mic button will be shown disabled. '
        'On web this requires a browser with Web Speech API support (Chrome) and microphone permission; '
        'on Windows this requires the OS speech recognition feature to be installed and enabled.',
        name: 'AgUiChatInput',
      );
    }
    if (mounted) setState(() => _sttAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening(keepText: true);
      return;
    }
    if (!_sttAvailable) {
      _showVoiceUnavailableMessage();
      return;
    }
    _voiceSessionBaseText = _ctrl.text;
    _liveTranscript.value = '';
    _waveform.value = List<double>.filled(_waveformBarCount, 0.0);
    _recordingStopwatch = Stopwatch()..start();
    _recordingElapsed.value = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _recordingElapsed.value = _recordingStopwatch?.elapsed ?? Duration.zero;
    });
    setState(() => _isListening = true);
    _openVoiceOverlay();
    unawaited(_startAmplitudeMetering());
    await _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        final text = result.recognizedWords;
        _liveTranscript.value = text;
        final base = _voiceSessionBaseText ?? '';
        final merged = base.isEmpty ? text : (text.isEmpty ? base : '$base $text');
        _ctrl.value = _ctrl.value.copyWith(text: merged, selection: TextSelection.collapsed(offset: merged.length));
        if (result.finalResult) _stopListening(keepText: true);
      },
      listenOptions: SpeechListenOptions(listenFor: const Duration(seconds: 60), pauseFor: const Duration(seconds: 5), partialResults: true),
    );
  }

  /// Runs a `record` session purely for real amplitude metering — speech_to_text's
  /// own onSoundLevelChange isn't implemented on Windows or web (confirmed against
  /// its plugin source: neither backend ever calls it). The recorded audio bytes
  /// are discarded; only the dBFS amplitude stream drives the waveform.
  ///
  /// Deliberately does NOT gate on `hasPermission()` first: `record`'s own platform
  /// support matrix lists permission-check support as unimplemented on Windows, so
  /// a `false`/unreliable result there would wrongly skip real metering every time.
  /// Instead this always attempts `startStream()` and arms a short watchdog — if no
  /// real amplitude event arrives in time (denied permission, unsupported platform
  /// config, etc.), it falls back to the synthetic waveform instead.
  Future<void> _startAmplitudeMetering() async {
    _receivedRealAmplitude = false;
    try {
      final audioStream = await _recorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits));
      _recorderAudioSub = audioStream.listen((_) {});
      _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(_onAmplitude);
      _amplitudeWatchdog = Timer(const Duration(milliseconds: 1500), () {
        if (!_receivedRealAmplitude && _isListening) {
          developer.log('record: no amplitude event received within 1.5s, falling back to a synthetic waveform', name: 'AgUiChatInput');
          unawaited(_amplitudeSub?.cancel());
          _amplitudeSub = null;
          _startSyntheticWaveform();
        }
      });
    } catch (error, stackTrace) {
      developer.log('record amplitude metering unavailable, falling back to a synthetic waveform', name: 'AgUiChatInput', error: error, stackTrace: stackTrace);
      _startSyntheticWaveform();
    }
  }

  /// dBFS: roughly -60 (quiet) to 0 (loudest) for normal speech — mapped linearly
  /// onto a 0..1 bar height, clamped so silence still shows a faint baseline.
  void _onAmplitude(Amplitude amplitude) {
    if (!mounted || !_isListening) return;
    _receivedRealAmplitude = true;
    final db = amplitude.current.clamp(-60.0, 0.0);
    final normalized = ((db + 60.0) / 60.0).clamp(0.05, 1.0);
    _pushWaveformLevel(normalized);
  }

  void _pushWaveformLevel(double normalized) {
    final next = List<double>.of(_waveform.value)
      ..removeAt(0)
      ..add(normalized);
    _waveform.value = next;
  }

  void _startSyntheticWaveform() {
    _syntheticWaveformTimer?.cancel();
    _syntheticWaveformTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || !_isListening) return;
      // Small random walk instead of pure noise, so it reads as organic movement.
      _syntheticLevel = (_syntheticLevel + (_syntheticRandom.nextDouble() - 0.5) * 0.35).clamp(0.15, 0.85);
      _pushWaveformLevel(_syntheticLevel);
    });
  }

  Future<void> _stopAmplitudeMetering() async {
    _amplitudeWatchdog?.cancel();
    _amplitudeWatchdog = null;
    _syntheticWaveformTimer?.cancel();
    _syntheticWaveformTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _recorderAudioSub?.cancel();
    _recorderAudioSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<void> _stopListening({required bool keepText}) async {
    if (_isListening) await _stt.stop();
    await _stopAmplitudeMetering();
    if (!keepText) {
      final base = _voiceSessionBaseText;
      if (base != null) {
        _ctrl.value = TextEditingValue(text: base, selection: TextSelection.collapsed(offset: base.length));
      }
    }
    _voiceSessionBaseText = null;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStopwatch?.stop();
    _recordingStopwatch = null;
    if (mounted) setState(() => _isListening = false);
    _closeVoiceOverlay();
  }

  void _showVoiceUnavailableMessage() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Voice input isn\'t available on this device or browser.')),
    );
  }

  void _openVoiceOverlay() {
    if (_voiceOverlayOpen) return;
    _voiceOverlayOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Captured so _closeVoiceOverlay can pop the exact Navigator this dialog
        // route was pushed onto — using the outer widget's own `context` with
        // `rootNavigator: true` popped the wrong Navigator whenever the app has
        // more than one (nested routing), which is why Cancel/Done did nothing.
        _voiceOverlayContext = dialogContext;
        return _VoiceRecordingOverlay(
          pulseAnim: _voicePulseAnim,
          waveform: _waveform,
          elapsed: _recordingElapsed,
          onStop: () => _stopListening(keepText: true),
          onCancel: () => _stopListening(keepText: false),
        );
      },
    ).then((_) {
      _voiceOverlayOpen = false;
      _voiceOverlayContext = null;
    });
  }

  void _closeVoiceOverlay() {
    final dialogContext = _voiceOverlayContext;
    if (_voiceOverlayOpen && dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  // ── File attachments ────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true, type: widget.acceptedExtensions != null ? FileType.custom : FileType.any, allowedExtensions: widget.acceptedExtensions);
    if (result == null || !mounted) return;
    setState(() {
      for (final f in result.files) {
        if (f.path != null) _attachments.add(AgUiFileAttachment(path: f.path!, name: f.name));
      }
    });
  }

  void _addDroppedFiles(List<DropItem> files) {
    if (!mounted) return;
    setState(() {
      for (final f in files) {
        _attachments.add(AgUiFileAttachment(path: f.path, name: f.name));
      }
    });
  }

  void _removeAttachment(int index) => setState(() => _attachments.removeAt(index));

  // ── Clipboard paste ─────────────────────────────────────────────────────────

  Future<bool> _tryPasteImage() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return false;
    final reader = await clipboard.read();
    if (!reader.canProvide(Formats.png) && !reader.canProvide(Formats.jpeg)) return false;

    final format = reader.canProvide(Formats.png) ? Formats.png : Formats.jpeg;
    final mimeType = reader.canProvide(Formats.png) ? 'image/png' : 'image/jpeg';

    final completer = Completer<Uint8List?>();
    reader.getFile(format, (file) async {
      completer.complete(await file.readAll());
    }, onError: (_) => completer.complete(null));

    final bytes = await completer.future;
    if (bytes == null || !mounted) return false;
    setState(() => _attachments.add(AgUiImageBytesAttachment(bytes: bytes, mimeType: mimeType, name: 'image.${mimeType.split('/').last}')));
    return true;
  }

  // ── Send ────────────────────────────────────────────────────────────────────

  void _send() {
    final text = _ctrl.text.trim();
    final atts = List<AgUiInputAttachment>.from(_attachments);
    if (text.isEmpty && atts.isEmpty) return;
    _ctrl.clear();
    setState(() => _attachments.clear());
    widget.onSend(text, atts);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEnabled = widget.enabled && !widget.loading;
    final hasFocus = _focusNode.hasFocus;
    final hasContent = _ctrl.text.trim().isNotEmpty || _attachments.isNotEmpty;
    final agTheme = AgThemeData.of(context);
    final accentColor = widget.isHil ? agTheme.hilColor ?? cs.primary : cs.primary;
    final onAccentColor = agTheme.onAccentColor ?? cs.onPrimary;

    // ── TextField (borderless — container provides the border) ───────────────
    final textField = Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          final ctrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) || HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight) || HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaLeft) || HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaRight);
          final shift = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) || HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
          if (ctrl || shift) {
            // Ctrl+Enter or Shift+Enter → insert newline at cursor position.
            final text = _ctrl.text;
            final selection = _ctrl.selection;
            final newText = text.replaceRange(selection.start, selection.end, '\n');
            _ctrl.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: selection.start + 1),
            );
            return KeyEventResult.handled;
          }
          if (isEnabled) {
            _send();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () async {
            await _tryPasteImage();
          },
        },
        child: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          enabled: isEnabled,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          textInputAction: TextInputAction.send,
          onSubmitted: isEnabled ? (_) => _send() : null,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(hintText: widget.isHil ? widget.hilHint : widget.hint, hintStyle: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.55)), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, disabledBorder: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 4)),
        ),
      ),
    );

    // ── Bottom toolbar (inside the container) ─────────────────────────────────
    final toolbar = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // [+] attach
          if (widget.enableAttachments) _ToolbarIconButton(icon: Icons.add_rounded, tooltip: 'Attach files', onTap: isEnabled ? _pickFiles : null, color: cs.onSurfaceVariant),

          // Leading actions (customizable via lib)
          if (widget.leadingActions != null && widget.leadingActions!.isNotEmpty) IconTheme(data: IconThemeData(size: 18, color: cs.onSurfaceVariant), child: Row(mainAxisSize: MainAxisSize.min, children: widget.leadingActions!)),

          // Voice mic — shown (disabled, with an explanatory tooltip) even when speech
          // recognition isn't available on this platform/browser, rather than hidden
          // outright, so it's clear the feature exists but can't be used right now.
          if (widget.enableVoice)
            _VoiceButton(
              isListening: _isListening,
              pulseAnim: _voicePulseAnim,
              // Stays tappable even when speech recognition is unavailable, so tapping
              // it surfaces an explanation (a snackbar) instead of silently doing nothing.
              tappable: isEnabled,
              unavailable: !_sttAvailable,
              onTap: _toggleListening,
              color: cs.onSurfaceVariant,
            ),

          const Spacer(),

          // Trailing actions (customizable via lib)
          if (widget.trailingActions != null && widget.trailingActions!.isNotEmpty) ...[IconTheme(data: IconThemeData(size: 18, color: cs.onSurfaceVariant), child: Row(mainAxisSize: MainAxisSize.min, children: widget.trailingActions!)), const SizedBox(width: 4)],

          // Send button — filled with accent color
          _SendButton(loading: widget.loading, canSend: isEnabled && hasContent, hasFocus: hasFocus, onTap: _send, accentColor: accentColor, onAccentColor: onAccentColor),
        ],
      ),
    );

    // ── Inner column ──────────────────────────────────────────────────────────
    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_attachments.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(6, 6, 6, 0), child: _AttachmentChips(attachments: _attachments, onRemove: _removeAttachment)),
        if (_isDragOver) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Drop files here', style: theme.textTheme.labelSmall?.copyWith(color: accentColor), textAlign: TextAlign.center)),
        textField,
        //Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.25)),
        toolbar,
      ],
    );

    // ── Border container + rotating sweep overlay when loading ────────────────
    final borderColor =
        _isDragOver
            ? accentColor
            : hasFocus
            ? accentColor.withValues(alpha: 0.8)
            : widget.loading
            ? accentColor.withValues(alpha: 0.35)
            : cs.outlineVariant.withValues(alpha: 0.7);
    //final borderWidth = (_isDragOver || hasFocus || widget.loading) ? 1.0 : 0.5;
    final borderWidth = 0.5;

    Widget container = Container(
      decoration: BoxDecoration(border: Border.all(color: borderColor, width: borderWidth), borderRadius: BorderRadius.circular(6), color: widget.isHil ? cs.tertiaryContainer.withValues(alpha: 0.18) : cs.surfaceContainerLow.withValues(alpha: 0.35)),
      child: Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(5), child: inner), if (widget.loading && widget.loadingOverlay != null) Positioned.fill(child: IgnorePointer(child: widget.loadingOverlay!))]),
    );

    // ── DropTarget wrapper ────────────────────────────────────────────────────
    if (widget.enableAttachments) {
      container = DropTarget(onDragDone: (details) => _addDroppedFiles(details.files), onDragEntered: (_) => setState(() => _isDragOver = true), onDragExited: (_) => setState(() => _isDragOver = false), child: container);
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (widget.actionBar != null) widget.actionBar!, container]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SendButton
// ─────────────────────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  const _SendButton({required this.loading, required this.canSend, required this.hasFocus, required this.onTap, required this.accentColor, required this.onAccentColor});

  final bool loading;
  final bool canSend;
  final bool hasFocus;
  final VoidCallback onTap;
  final Color accentColor;
  final Color onAccentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      // Neutral spinner — accent is reserved for the "ready to act" state
      return SizedBox(width: 24, height: 24, child: Padding(padding: const EdgeInsets.all(5), child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSurfaceVariant.withValues(alpha: 0.5))));
    }

    // Accent only when actually clickable — no hasFocus tier to avoid
    // the "mauve flash" between text-cleared and loading-start.
    final bgAlpha = canSend ? 1.0 : 0.13;
    final fgAlpha = canSend ? 1.0 : 0.38;

    return Tooltip(
      message: 'Send',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: accentColor.withValues(alpha: bgAlpha), borderRadius: BorderRadius.circular(6)),
        child: Material(color: Colors.transparent, child: InkWell(onTap: canSend ? onTap : null, borderRadius: BorderRadius.circular(6), child: Center(child: Icon(Icons.arrow_upward_rounded, size: 14, color: canSend ? onAccentColor : accentColor.withValues(alpha: fgAlpha))))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ToolbarIconButton
// ─────────────────────────────────────────────────────────────────────────────

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({required this.icon, required this.tooltip, required this.onTap, required this.color, this.dimmed = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  /// Forces the dimmed (disabled-looking) appearance even when [onTap] is non-null —
  /// for buttons that stay tappable (e.g. to show an explanation) but shouldn't look active.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final isDim = dimmed || onTap == null;
    return Tooltip(message: tooltip, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 18, color: isDim ? color.withValues(alpha: 0.35) : color))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VoiceButton
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({required this.isListening, required this.pulseAnim, required this.tappable, required this.onTap, required this.color, this.unavailable = false});

  final bool isListening;
  final Animation<double> pulseAnim;

  /// Whether the button can be tapped at all (the overall input is enabled).
  /// Unlike the old `enabled` flag, this stays `true` even when speech
  /// recognition itself is unavailable, so a tap can surface why — see [unavailable].
  final bool tappable;
  final VoidCallback onTap;
  final Color color;

  /// True when speech recognition isn't available on this platform/browser
  /// (e.g. no Web Speech API support, mic permission denied, OS speech
  /// recognition not installed). Dims the icon and changes the tooltip;
  /// the button stays tappable so the user gets an explanation instead of silence.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, _) {
        return _ToolbarIconButton(
          icon: isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          tooltip: unavailable
              ? 'Voice input unavailable on this device/browser'
              : isListening
              ? 'Stop listening'
              : 'Voice input',
          color: isListening ? cs.error.withValues(alpha: pulseAnim.value) : color,
          dimmed: unavailable,
          onTap: tappable ? onTap : null,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VoiceRecordingOverlay
// ─────────────────────────────────────────────────────────────────────────────

/// A small, centered pill shown while listening — a live waveform reacting to
/// sound level, an elapsed-time readout, and cancel/done controls. Minimal by
/// design, matching the compact voice-recording bar pattern used by ChatGPT
/// and other mobile chat apps rather than a full dialog.
class _VoiceRecordingOverlay extends StatelessWidget {
  const _VoiceRecordingOverlay({required this.pulseAnim, required this.waveform, required this.elapsed, required this.onStop, required this.onCancel});

  final Animation<double> pulseAnim;
  final ValueListenable<List<double>> waveform;
  final ValueListenable<Duration> elapsed;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  static String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Dialog(
      backgroundColor: cs.surfaceContainerHigh,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (context, _) => Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.error.withValues(alpha: 0.5 + 0.5 * pulseAnim.value))),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<Duration>(
                valueListenable: elapsed,
                builder: (context, value, _) => Text(_formatElapsed(value), style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<List<double>>(
                  valueListenable: waveform,
                  builder: (context, levels, _) {
                    return SizedBox(
                      height: 28,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (final level in levels)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: 2.5,
                              height: 4 + level * 22,
                              decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(2)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 4),
              IconButton(onPressed: onCancel, icon: const Icon(Icons.close_rounded, size: 18), tooltip: 'Cancel', visualDensity: VisualDensity.compact, color: cs.onSurfaceVariant),
              IconButton(onPressed: onStop, icon: const Icon(Icons.check_rounded, size: 18), tooltip: 'Done', visualDensity: VisualDensity.compact, style: IconButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AttachmentChips
// ─────────────────────────────────────────────────────────────────────────────

class _AttachmentChips extends StatelessWidget {
  const _AttachmentChips({required this.attachments, required this.onRemove});

  final List<AgUiInputAttachment> attachments;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [for (var i = 0; i < attachments.length; i++) Chip(avatar: _avatar(context, attachments[i]), label: Text(attachments[i].name ?? _fallbackName(attachments[i]), style: Theme.of(context).textTheme.labelSmall, overflow: TextOverflow.ellipsis), deleteIcon: const Icon(Icons.close, size: 14), onDeleted: () => onRemove(i), visualDensity: VisualDensity.compact)],
    );
  }

  Widget _avatar(BuildContext context, AgUiInputAttachment att) {
    if (att is AgUiImageBytesAttachment) {
      return ClipRRect(borderRadius: BorderRadius.circular(2), child: Image.memory(att.bytes, width: 16, height: 16, fit: BoxFit.cover));
    }
    return Icon(_icon(att), size: 16, color: Theme.of(context).colorScheme.primary);
  }

  IconData _icon(AgUiInputAttachment att) {
    if (att is AgUiImageBytesAttachment) return Icons.image_outlined;
    if (att is AgUiFileAttachment) {
      final ext = (att.name ?? '').split('.').last.toLowerCase();
      return switch (ext) {
        'pdf' => Icons.picture_as_pdf_outlined,
        'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => Icons.image_outlined,
        'mp3' || 'wav' || 'ogg' => Icons.audio_file_outlined,
        'mp4' || 'mov' || 'avi' => Icons.video_file_outlined,
        _ => Icons.attach_file_rounded,
      };
    }
    return Icons.attach_file_rounded;
  }

  String _fallbackName(AgUiInputAttachment att) => switch (att) {
    AgUiFileAttachment _ => 'File',
    AgUiImageBytesAttachment _ => 'Image',
  };
}
