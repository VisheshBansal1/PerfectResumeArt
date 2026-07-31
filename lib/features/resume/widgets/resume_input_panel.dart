// ─────────────────────────────────────────────────────────────────────────
// RESUME INPUT PANEL
//
// One shared "give me your resume" component used identically everywhere
// the app needs resume text — ATS Checker, JD Keyword Match, and anywhere
// added later. Centralizing this guarantees every entry point extracts
// text the same way and writes to the same shared resumeContextProvider,
// so results are consistent across the whole app instead of drifting
// screen to screen.
//
// Supports: tap-to-browse, drag-and-drop (web), and paste-text.
//
// REQUIRES a new dependency for drag-and-drop: add to pubspec.yaml
//   desktop_drop: ^0.4.4
// then run `flutter pub get`. (cross_file comes with it automatically.)
// Everything else in this file uses packages already in your project.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../providers/providers.dart';
import '../../../providers/resume_context_provider.dart';

enum ResumeInputMode { upload, paste }

const List<String> kResumeAllowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

/// Everything a parent screen needs after the panel produces resume text —
/// bytes/fileName/extension are only populated when the source was a real
/// file (needed by screens that upload-and-store the file, like the ATS
/// Checker); screens that only need text (like JD Keyword Match) can just
/// read [text].
class ResumeInputResult {
  final String text;
  final Uint8List? bytes;
  final String? fileName;
  final String? extension;
  final bool isFromFile;

  const ResumeInputResult({
    required this.text,
    this.bytes,
    this.fileName,
    this.extension,
    required this.isFromFile,
  });
}

class ResumeInputPanel extends ConsumerStatefulWidget {
  final Color accentColor;
  final String source; // tag stored in resumeContextProvider, e.g. 'ats', 'jd_match'
  final void Function(ResumeInputResult result)? onResumeReady;
  final void Function()? onCleared;
  final bool allowPaste;

  const ResumeInputPanel({
    super.key,
    this.accentColor = AppTheme.primary,
    required this.source,
    this.onResumeReady,
    this.onCleared,
    this.allowPaste = true,
  });

  @override
  ConsumerState<ResumeInputPanel> createState() => ResumeInputPanelState();
}

class ResumeInputPanelState extends ConsumerState<ResumeInputPanel> {
  ResumeInputMode _mode = ResumeInputMode.upload;
  final TextEditingController pasteController = TextEditingController();
  Timer? _pasteDebounce;

  bool _isExtracting = false;
  bool _dragHover = false;
  String? _selectedFileName;
  String? _fileType;
  String? _error;

  @override
  void dispose() {
    _pasteDebounce?.cancel();
    pasteController.dispose();
    super.dispose();
  }

  Future<void> _handleBytes(Uint8List bytes, String fileName, String extension) async {
    setState(() {
      _isExtracting = true;
      _selectedFileName = fileName;
      _fileType = extension;
      _error = null;
    });
    try {
      await ref
          .read(resumeUploadProvider.notifier)
          .extractTextFromBytes(bytes: bytes, extension: extension);
      final text = ref.read(resumeUploadProvider).extractedText ?? '';
      if (text.trim().length < 50) {
        setState(() {
          _error = 'Could not extract enough text — is this a scanned image or a text-based file?';
        });
        return;
      }
      // setResumeWithPdf (not just setResume) so the raw bytes are retained in
      // the shared context — Human Review and any future tool that needs the
      // original file can reuse it without asking the user to upload again.
      await ref.read(resumeContextProvider.notifier).setResumeWithPdf(
            text,
            source: widget.source,
            pdfBytes: bytes,
            originalFileName: fileName,
          );
      widget.onResumeReady?.call(
        ResumeInputResult(
          text: text,
          bytes: bytes,
          fileName: fileName,
          extension: extension,
          isFromFile: true,
        ),
      );
    } catch (e) {
      setState(() => _error = friendlyError(e, fallback: 'Could not read this file. Please try again.'));
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _handleMobileFile(File file, String extension) async {
    setState(() {
      _isExtracting = true;
      _selectedFileName = file.path.split(Platform.pathSeparator).last;
      _fileType = extension;
      _error = null;
    });
    try {
      await ref.read(resumeUploadProvider.notifier).extractText(file);
      final text = ref.read(resumeUploadProvider).extractedText ?? '';
      if (text.trim().length < 50) {
        setState(() {
          _error = 'Could not extract enough text — is this a scanned image or a text-based file?';
        });
        return;
      }
      final bytes = await file.readAsBytes();
      await ref.read(resumeContextProvider.notifier).setResumeWithPdf(
            text,
            source: widget.source,
            pdfBytes: bytes,
            originalFileName: _selectedFileName ?? 'resume.$extension',
          );
      widget.onResumeReady?.call(
        ResumeInputResult(
          text: text,
          bytes: bytes,
          fileName: _selectedFileName,
          extension: extension,
          isFromFile: true,
        ),
      );
    } catch (e) {
      setState(() => _error = friendlyError(e, fallback: 'Could not read this file. Please try again.'));
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  String? _validateExtension(String? name) {
    final ext = (name ?? '').split('.').last.toLowerCase();
    if (!kResumeAllowedExtensions.contains(ext)) return null;
    return ext;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kResumeAllowedExtensions,
      withData: kIsWeb,
    );
    if (result == null) return;
    final picked = result.files.single;
    final ext = _validateExtension(picked.name);
    if (ext == null) {
      setState(() => _error = 'Unsupported file type. Use PDF, JPG, or PNG.');
      return;
    }
    if (kIsWeb) {
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _error = 'Could not read file. Please try again.');
        return;
      }
      await _handleBytes(bytes, picked.name, ext);
    } else {
      if (picked.path == null) return;
      final file = File(picked.path!);
      if (!await file.exists()) return;
      await _handleMobileFile(file, ext);
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    final dropped = files.first;
    final ext = _validateExtension(dropped.name);
    if (ext == null) {
      setState(() => _error = 'Unsupported file type. Use PDF, JPG, or PNG.');
      return;
    }
    final bytes = await dropped.readAsBytes();
    await _handleBytes(bytes, dropped.name, ext);
  }

  void _clear() {
    setState(() {
      _selectedFileName = null;
      _fileType = null;
      _error = null;
    });
    ref.read(resumeUploadProvider.notifier).reset();
    widget.onCleared?.call();
  }

  void _onPasteChanged(String value) {
    setState(() {}); // keep this widget's own UI (e.g. char count) responsive
    _pasteDebounce?.cancel();
    _pasteDebounce = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      final text = pasteController.text;
      if (text.trim().length < 50) return;
      // Debounced: this writes to Firestore via resumeContextProvider, so we
      // don't want to fire on every keystroke. Parent screens that show an
      // Instant Scan read from the shared context/upload state, so their
      // scan updates shortly after typing pauses, not on every character.
      await ref.read(resumeContextProvider.notifier).setResume(text, source: widget.source);
      widget.onResumeReady?.call(ResumeInputResult(text: text, isFromFile: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.allowPaste) ...[
          _buildModeToggle(),
          const SizedBox(height: 14),
        ],
        if (_mode == ResumeInputMode.upload || !widget.allowPaste) ...[
          _buildDropZone(),
          if (_selectedFileName != null) _buildFilePreview(),
        ] else
          _buildPasteArea(),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildModeToggle() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: widget.accentColor.withOpacity(0.06),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        Expanded(
          child: _ModeTab(
            label: 'Upload File',
            icon: Icons.upload_file_outlined,
            selected: _mode == ResumeInputMode.upload,
            color: widget.accentColor,
            onTap: () => setState(() => _mode = ResumeInputMode.upload),
          ),
        ),
        Expanded(
          child: _ModeTab(
            label: 'Paste Text',
            icon: Icons.content_paste_outlined,
            selected: _mode == ResumeInputMode.paste,
            color: widget.accentColor,
            onTap: () => setState(() => _mode = ResumeInputMode.paste),
          ),
        ),
      ],
    ),
  );

  Widget _buildDropZone() {
    final zone = GestureDetector(
      onTap: _isExtracting ? null : _pickFile,
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(12),
        color: _dragHover ? widget.accentColor : widget.accentColor.withOpacity(0.4),
        strokeWidth: _dragHover ? 2.2 : 1.5,
        dashPattern: const [8, 4],
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _dragHover ? widget.accentColor.withOpacity(0.08) : widget.accentColor.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isExtracting
              ? Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.accentColor),
                    ),
                    const SizedBox(height: 12),
                    const Text('Reading resume...', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                )
              : Column(
                  children: [
                    Icon(
                      _dragHover ? Icons.file_download_outlined : Icons.upload_file_outlined,
                      size: 36,
                      color: widget.accentColor.withOpacity(0.7),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _dragHover
                          ? 'Drop to upload'
                          : kIsWeb
                              ? 'Tap to browse, or drag a file here'
                              : 'Tap to select resume',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text('PDF, JPG, or PNG', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
        ),
      ),
    );

    // Drag-and-drop only makes sense where an OS/browser drag gesture exists.
    if (!kIsWeb) return zone;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragHover = true),
      onDragExited: (_) => setState(() => _dragHover = false),
      onDragDone: (details) async {
        setState(() => _dragHover = false);
        await _handleDroppedFiles(details.files);
      },
      child: zone,
    );
  }

  Widget _buildFilePreview() {
    final uploadState = ref.watch(resumeUploadProvider);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.accentColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            _fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image_outlined,
            color: widget.accentColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName ?? 'resume',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                if (uploadState.extractedText != null)
                  Text(
                    'Ready — ${uploadState.extractedText!.split(RegExp(r"\s+")).length} words detected',
                    style: TextStyle(fontSize: 11.5, color: widget.accentColor),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _clear,
            child: Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPasteArea() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      border: Border.all(color: widget.accentColor.withOpacity(0.25)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextField(
      controller: pasteController,
      onChanged: _onPasteChanged,
      maxLines: 10,
      minLines: 6,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(14),
        hintText: 'Paste your resume text here — no file needed. Copy everything (contact info, '
            'experience, education, skills) and paste it here.',
        hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
      ),
    ),
  );
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
