import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../client/app_client/api/uploads_api.dart';
import '../shell/ag_artifact_card.dart';
import '../theme/ag_artifacts_theme.dart';

/// Document / link / pasted-text intake widget.
///
/// Agent props:
/// ```json
/// {
///   "title": "Candidate CV",
///   "description": "Upload the resume, share a link, or paste its text.",
///   "sources": ["upload", "url", "paste"],
///   "accept": ".pdf,.docx,.txt,.md",
///   "maxSizeMb": 2,
///   "placeholder": "https://…",
///   "submitLabel": "Continue"
/// }
/// ```
///
/// It only *collects* — it never reads a document itself. When submitted, it calls `props['__onSubmit']`
/// with one small JSON envelope, so a workflow or agent can branch on `kind` (a scrape node for a link, a
/// document-extraction node for a file, the text as is) without guessing what it was handed:
/// ```
/// {"kind":"file","fileId":"…","name":"resume.pdf","mime":"application/pdf","size":84012}
/// {"kind":"url","url":"https://…"}
/// {"kind":"text","content":"…"}
/// ```
/// A file is uploaded to the platform first through `props['__upload']` (the chat injects it from
/// `onUploadFile`); the reply carries only its `fileId`. Mirrors the React `SourceInput`.
class AgSourceInput extends StatefulWidget {
  const AgSourceInput({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  State<AgSourceInput> createState() => _AgSourceInputState();
}

enum _Source { upload, url, paste }

const _sourceLabels = {_Source.upload: 'Upload', _Source.url: 'Link', _Source.paste: 'Paste'};

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.hasAuthority && (uri.scheme == 'http' || uri.scheme == 'https');
}

class _AgSourceInputState extends State<AgSourceInput> {
  late final List<_Source> _sources;
  late _Source _source;
  late final List<String> _accepted;
  late final double _maxSizeMb;

  final _url = TextEditingController();
  final _paste = TextEditingController();
  String? _fileName;
  Uint8List? _fileBytes;
  bool _dragging = false;
  bool _submitted = false;
  bool _uploading = false;
  String? _error;
  String? _sentNote;

  @override
  void initState() {
    super.initState();
    final raw = widget.props['sources'];
    final picked = raw is List ? _Source.values.where((s) => raw.contains(s.name)).toList() : <_Source>[];
    _sources = picked.isEmpty ? _Source.values.toList() : picked;
    _source = _sources.first;
    final accept = (widget.props['accept'] as String?)?.trim();
    _accepted = (accept == null || accept.isEmpty ? '.pdf,.docx,.txt,.md' : accept).split(',').map((e) => e.trim().replaceFirst(RegExp(r'^\.'), '').toLowerCase()).where((e) => e.isNotEmpty).toList();
    final max = widget.props['maxSizeMb'];
    _maxSizeMb = max is num && max > 0 ? max.toDouble() : 2;
    _url.addListener(() => setState(() {}));
    _paste.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _url.dispose();
    _paste.dispose();
    super.dispose();
  }

  String get _acceptLabel => _accepted.map((e) => e.toUpperCase()).join(', ');

  void _take(String name, Uint8List bytes) {
    if (_submitted) return;
    if (_accepted.isNotEmpty && !_accepted.contains(_extensionOf(name))) {
      setState(() => _error = '$name is not a supported file. Use $_acceptLabel.');
      return;
    }
    if (bytes.length > _maxSizeMb * 1024 * 1024) {
      setState(() => _error = '$name is ${_formatSize(bytes.length)} — the limit is ${_maxSizeMb.toStringAsFixed(_maxSizeMb % 1 == 0 ? 0 : 1)} MB.');
      return;
    }
    setState(() {
      _error = null;
      _fileName = name;
      _fileBytes = bytes;
    });
  }

  Future<void> _browse() async {
    if (_submitted) return;
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: _accepted, withData: true);
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file != null && bytes != null) _take(file.name, bytes);
  }

  Future<void> _dropped(List<DropItem> items) async {
    final item = items.firstOrNull;
    if (item == null) return;
    _take(item.name, await item.readAsBytes());
  }

  bool get _ready => switch (_source) {
    _Source.upload => _fileBytes != null,
    _Source.url => _isHttpUrl(_url.text.trim()),
    _Source.paste => _paste.text.trim().isNotEmpty,
  };

  Future<void> _submit() async {
    final onSubmit = widget.props['__onSubmit'] as Function?;
    if (onSubmit == null || _submitted || _uploading || !_ready) return;
    final Map<String, Object> envelope;
    final String note;
    switch (_source) {
      case _Source.upload:
        final upload = widget.props['__upload'] as Future<UploadedFile> Function(String, Uint8List)?;
        if (upload == null) {
          setState(() => _error = 'Uploading is not available here.');
          return;
        }
        setState(() {
          _uploading = true;
          _error = null;
        });
        try {
          final uploaded = await upload(_fileName!, _fileBytes!);
          envelope = {'kind': 'file', 'fileId': uploaded.fileId, 'name': uploaded.name, 'mime': uploaded.mimeType, 'size': uploaded.size};
          note = '${uploaded.name} · ${_formatSize(uploaded.size)}';
        } catch (e) {
          if (mounted) {
            setState(() {
              _uploading = false;
              _error = 'Could not upload the file. Try again.';
            });
          }
          return;
        }
        if (!mounted) return;
        setState(() => _uploading = false);
      case _Source.url:
        final value = _url.text.trim();
        envelope = {'kind': 'url', 'url': value};
        note = value;
      case _Source.paste:
        final value = _paste.text.trim();
        envelope = {'kind': 'text', 'content': value};
        note = 'Pasted text · ${value.length} characters';
    }
    setState(() {
      _submitted = true;
      _sentNote = note;
    });
    onSubmit(jsonEncode(envelope));
  }

  InputDecoration _decoration(ColorScheme cs, {String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outlineVariant)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outlineVariant)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.primary, width: 1.5)),
  );

  Widget _tabs(ColorScheme cs, String? fontFamily) {
    return Container(
      padding: const EdgeInsets.all(3),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(9), border: Border.all(color: cs.outlineVariant)),
      child: Row(
        children: [
          for (final s in _sources)
            Expanded(
              child: GestureDetector(
                onTap: _submitted ? null : () => setState(() {
                  _source = s;
                  _error = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: s == _source ? cs.surface : Colors.transparent, borderRadius: BorderRadius.circular(7), border: s == _source ? Border.all(color: cs.outlineVariant) : null),
                  child: Text(_sourceLabels[s]!, style: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: s == _source ? 1 : 0.6))),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dropZone(ColorScheme cs, String? fontFamily) {
    final hasFile = _fileName != null;
    Widget zone = InkWell(
      onTap: _submitted ? null : _browse,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _dragging ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _dragging || hasFile ? cs.primary : cs.outline, width: 1.5),
        ),
        child: hasFile
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_fileName!, textAlign: TextAlign.center, style: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 4),
                Text('${_formatSize(_fileBytes!.length)}${_submitted ? '' : ' · tap to replace'}', style: TextStyle(fontFamily: fontFamily, fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.upload_file_rounded, size: 22, color: cs.onSurface.withValues(alpha: 0.6)),
                const SizedBox(height: 4),
                Text('Drop a file here or browse', style: TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text('$_acceptLabel · up to ${_maxSizeMb.toStringAsFixed(_maxSizeMb % 1 == 0 ? 0 : 1)} MB', style: TextStyle(fontFamily: fontFamily, fontSize: 11, color: cs.onSurface.withValues(alpha: 0.55))),
              ]),
      ),
    );
    return DropTarget(onDragEntered: (_) => setState(() => _dragging = true), onDragExited: (_) => setState(() => _dragging = false), onDragDone: (d) {
      setState(() => _dragging = false);
      _dropped(d.files);
    }, child: zone);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fontFamily = AgArtifactsThemeData.of(context).fontFamily;
    final title = widget.props['title'] as String? ?? 'Add a document';
    final description = widget.props['description'] as String?;
    final placeholder = widget.props['placeholder'] as String?;
    final submitLabel = widget.props['submitLabel'] as String? ?? 'Continue';
    final fieldStyle = TextStyle(fontFamily: fontFamily, fontSize: 13);

    // Answered/disabled dimming is owned by the chat panel's message bubble, not this widget — see AgQuestionForm.
    return AgArtifactCard(
      title: title,
      icon: Icons.upload_file_rounded,
      type: 'Source',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (description != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(description, style: TextStyle(fontFamily: fontFamily, fontSize: 13, color: cs.onSurface.withValues(alpha: 0.75)))),
          if (_sources.length > 1) _tabs(cs, fontFamily),
          switch (_source) {
            _Source.upload => _dropZone(cs, fontFamily),
            _Source.url => TextField(controller: _url, enabled: !_submitted, keyboardType: TextInputType.url, decoration: _decoration(cs, hint: placeholder ?? 'https://…'), style: fieldStyle, onSubmitted: (_) => _submit()),
            _Source.paste => TextField(controller: _paste, enabled: !_submitted, minLines: 6, maxLines: 10, decoration: _decoration(cs, hint: placeholder ?? 'Paste the text here'), style: fieldStyle),
          },
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(fontFamily: fontFamily, fontSize: 12, color: cs.error))),
          if (_sentNote != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Sent — $_sentNote', style: TextStyle(fontFamily: fontFamily, fontSize: 12, color: cs.onSurface.withValues(alpha: 0.65)))),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitted || _uploading || !_ready ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            child: Text(_uploading ? 'Uploading…' : submitLabel, style: TextStyle(fontFamily: fontFamily, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
