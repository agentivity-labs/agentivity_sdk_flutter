import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.enableVoice = false,
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
    if (_isListening) _stt.stop();
    super.dispose();
  }

  // ── Speech-to-text ──────────────────────────────────────────────────────────

  Future<void> _initStt() async {
    final available = await _stt.initialize(onError: (_) => setState(() => _isListening = false));
    if (mounted) setState(() => _sttAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (!_sttAvailable) return;
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        final text = result.recognizedWords;
        final current = _ctrl.text;
        final merged = current.isEmpty ? text : '$current $text';
        _ctrl.value = _ctrl.value.copyWith(text: merged, selection: TextSelection.collapsed(offset: merged.length));
        if (result.finalResult) setState(() => _isListening = false);
      },
      listenOptions: SpeechListenOptions(listenFor: const Duration(seconds: 60), pauseFor: const Duration(seconds: 5), partialResults: true),
    );
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

          // Voice mic
          if (widget.enableVoice && _sttAvailable) _VoiceButton(isListening: _isListening, pulseAnim: _voicePulseAnim, enabled: isEnabled, onTap: _toggleListening, color: cs.onSurfaceVariant),

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
  const _ToolbarIconButton({required this.icon, required this.tooltip, required this.onTap, required this.color});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(message: tooltip, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 18, color: onTap != null ? color : color.withValues(alpha: 0.35)))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VoiceButton
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({required this.isListening, required this.pulseAnim, required this.enabled, required this.onTap, required this.color});

  final bool isListening;
  final Animation<double> pulseAnim;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, _) {
        return _ToolbarIconButton(icon: isListening ? Icons.mic_rounded : Icons.mic_none_rounded, tooltip: isListening ? 'Stop listening' : 'Voice input', color: isListening ? cs.error.withValues(alpha: pulseAnim.value) : color, onTap: enabled ? onTap : null);
      },
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
