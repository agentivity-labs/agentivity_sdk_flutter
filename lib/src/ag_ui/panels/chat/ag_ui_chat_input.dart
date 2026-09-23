import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
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
    this.onTranscribeAudio,
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

  /// Shows a microphone button. Actual dictation only works when
  /// [onTranscribeAudio] is also provided — see its doc for why.
  final bool enableVoice;

  /// Uploads the recorded audio for server-side transcription and returns the
  /// transcribed text (or `null`/throws on failure). `null` (the default) means
  /// voice transcription isn't available — the mic is shown disabled with an
  /// explanatory tooltip rather than hidden outright, so it's clear the feature
  /// exists but isn't configured. The widget stays IO-free itself (like [onSend]):
  /// the host app owns the actual network call, typically gated on a capability
  /// check (e.g. `client.voice.checkStatus()`) rather than passed unconditionally.
  final Future<String?> Function(Uint8List audioBytes, String mimeType)? onTranscribeAudio;

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

  // Voice — one capture only: `record` is used both for the live waveform
  // (real dBFS amplitude, via onAmplitudeChanged) and for the audio itself
  // (raw PCM, wrapped into a WAV file on stop and handed to
  // widget.onTranscribeAudio for server-side transcription). There is
  // deliberately no local/on-device speech engine and no second concurrent
  // capture — an earlier attempt to run a second capture just for amplitude
  // alongside a separate on-device recognizer measurably degraded that
  // recognizer's accuracy (two sessions competing for the same input device).
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _voiceOverlayOpen = false;
  BuildContext? _voiceOverlayContext;
  BytesBuilder? _pcmChunks;
  StreamSubscription<Uint8List>? _audioStreamSub;
  StreamSubscription<Amplitude>? _amplitudeSub;
  static const int _waveformBarCount = 24;
  static const int _sampleRate = 16000;
  final ValueNotifier<List<double>> _waveform = ValueNotifier<List<double>>(List<double>.filled(_waveformBarCount, 0.0));
  Stopwatch? _recordingStopwatch;
  Timer? _recordingTimer;
  final ValueNotifier<Duration> _recordingElapsed = ValueNotifier<Duration>(Duration.zero);

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
  }

  @override
  void dispose() {
    if (_ownsController) _ctrl.dispose();
    _focusNode.dispose();
    _pulseCtrl.dispose();
    _waveform.dispose();
    _recordingElapsed.dispose();
    _recordingTimer?.cancel();
    _amplitudeSub?.cancel();
    _audioStreamSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Voice recording ─────────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _finishRecording(keepAudio: true);
      return;
    }
    if (widget.onTranscribeAudio == null) {
      _showVoiceUnavailableMessage();
      return;
    }
    _pcmChunks = BytesBuilder();
    _waveform.value = List<double>.filled(_waveformBarCount, 0.0);
    _recordingStopwatch = Stopwatch()..start();
    _recordingElapsed.value = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _recordingElapsed.value = _recordingStopwatch?.elapsed ?? Duration.zero;
    });
    setState(() => _isRecording = true);
    _openVoiceOverlay();
    try {
      final stream = await _recorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: _sampleRate, numChannels: 1));
      _audioStreamSub = stream.listen((chunk) => _pcmChunks?.add(chunk));
      _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(_onAmplitude);
    } catch (error, stackTrace) {
      developer.log('record.startStream() threw', name: 'AgUiChatInput', error: error, stackTrace: stackTrace);
      await _finishRecording(keepAudio: false);
      _showVoiceUnavailableMessage();
    }
  }

  /// dBFS: roughly -60 (quiet) to 0 (loudest) for normal speech — mapped
  /// linearly onto a 0..1 bar height, clamped so silence still shows a faint
  /// baseline. This is the only microphone capture in the widget, so there's
  /// nothing else competing for the input device — the waveform is real.
  void _onAmplitude(Amplitude amplitude) {
    if (!mounted || !_isRecording) return;
    final db = amplitude.current.clamp(-60.0, 0.0);
    final normalized = ((db + 60.0) / 60.0).clamp(0.05, 1.0);
    final next = List<double>.of(_waveform.value)
      ..removeAt(0)
      ..add(normalized);
    _waveform.value = next;
  }

  Future<void> _finishRecording({required bool keepAudio}) async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    if (await _recorder.isRecording()) await _recorder.stop();
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStopwatch?.stop();
    _recordingStopwatch = null;
    final pcm = _pcmChunks?.toBytes();
    _pcmChunks = null;
    if (mounted) setState(() => _isRecording = false);
    _closeVoiceOverlay();

    final onTranscribeAudio = widget.onTranscribeAudio;
    if (!keepAudio || pcm == null || pcm.isEmpty || onTranscribeAudio == null) return;

    final wavBytes = _pcm16ToWav(pcm, sampleRate: _sampleRate, numChannels: 1);
    if (mounted) setState(() => _isTranscribing = true);
    try {
      final text = await onTranscribeAudio(wavBytes, 'audio/wav');
      if (!mounted) return;
      final trimmed = text?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        final current = _ctrl.text;
        final merged = current.isEmpty ? trimmed : '$current $trimmed';
        _ctrl.value = TextEditingValue(text: merged, selection: TextSelection.collapsed(offset: merged.length));
      }
    } catch (error, stackTrace) {
      developer.log('onTranscribeAudio threw', name: 'AgUiChatInput', error: error, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Voice transcription failed.')));
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  void _showVoiceUnavailableMessage() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Voice input isn\'t available right now.')),
    );
  }

  /// Wraps raw 16-bit PCM (mono) into a minimal WAV container — `record`'s
  /// pcm16bits stream encoder is the one format its own compatibility matrix
  /// confirms works on every platform this app targets, including Windows and
  /// web, but it's headerless; the backend's transcription endpoint (and
  /// Whisper itself) expects a standard audio file.
  static Uint8List _pcm16ToWav(Uint8List pcmBytes, {required int sampleRate, required int numChannels}) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataLength = pcmBytes.length;

    final header = BytesBuilder();
    void writeAscii(String s) => header.add(s.codeUnits);
    void writeUint32(int v) => header.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    void writeUint16(int v) => header.add([v & 0xFF, (v >> 8) & 0xFF]);

    writeAscii('RIFF');
    writeUint32(36 + dataLength);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeUint32(16); // fmt chunk size
    writeUint16(1); // PCM
    writeUint16(numChannels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeAscii('data');
    writeUint32(dataLength);
    header.add(pcmBytes);
    return header.toBytes();
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
          onStop: () => _finishRecording(keepAudio: true),
          onCancel: () => _finishRecording(keepAudio: false),
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

  static const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp'};

  Future<void> _pickFiles() async {
    // withData: true so picked images arrive as bytes (AgUiImageBytesAttachment)
    // the same way clipboard-pasted ones already do — a bare `path` is
    // meaningless on web, and the vision-attachment path needs raw bytes to
    // base64-encode regardless of platform.
    final result = await FilePicker.pickFiles(allowMultiple: true, type: widget.acceptedExtensions != null ? FileType.custom : FileType.any, allowedExtensions: widget.acceptedExtensions, withData: true);
    if (result == null || !mounted) return;
    setState(() {
      for (final f in result.files) {
        final extension = f.extension?.toLowerCase() ?? f.name.split('.').last.toLowerCase();
        if (f.bytes != null && _imageExtensions.contains(extension)) {
          final mimeExtension = extension == 'jpg' ? 'jpeg' : extension;
          _attachments.add(AgUiImageBytesAttachment(bytes: f.bytes!, name: f.name, mimeType: 'image/$mimeExtension'));
        } else if (f.path != null) {
          _attachments.add(AgUiFileAttachment(path: f.path!, name: f.name));
        }
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

          // Voice mic — shown disabled (with an explanatory tooltip) when
          // onTranscribeAudio isn't provided, rather than hidden outright, so
          // it's clear the feature exists but isn't configured/available.
          if (widget.enableVoice && _isTranscribing)
            const Padding(padding: EdgeInsets.all(5), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
          else if (widget.enableVoice)
            _VoiceButton(
              isListening: _isRecording,
              pulseAnim: _voicePulseAnim,
              // Stays tappable even when unavailable, so tapping it surfaces an
              // explanation (a snackbar) instead of silently doing nothing.
              tappable: isEnabled,
              unavailable: widget.onTranscribeAudio == null,
              onTap: _toggleRecording,
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
              IconButton(
                // Pops using this button's OWN context — the standard, guaranteed-correct
                // way to close a dialog from inside itself, regardless of how many
                // Navigators the app has. Also invokes onCancel for the state-side cleanup.
                onPressed: () {
                  onCancel();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Cancel',
                visualDensity: VisualDensity.compact,
                color: cs.onSurfaceVariant,
              ),
              IconButton(
                onPressed: () {
                  onStop();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                tooltip: 'Done',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
              ),
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
