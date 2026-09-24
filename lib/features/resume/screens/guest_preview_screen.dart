// lib/features/resume/screens/guest_preview_screen.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for guest result
// ─────────────────────────────────────────────────────────────────────────────

class _GuestResult {
  final int atsScore;
  final String overallAssessment;
  final List<String> quickFindings; // shown to guest
  final int criticalIssuesCount; // shown (count only)
  final List<String> missingKeywords; // locked
  final List<String> strengthAreas; // locked
  final List<String> redFlags; // locked

  const _GuestResult({
    required this.atsScore,
    required this.overallAssessment,
    required this.quickFindings,
    required this.criticalIssuesCount,
    required this.missingKeywords,
    required this.strengthAreas,
    required this.redFlags,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

enum _Step { upload, analyzing, result, error }

class GuestPreviewScreen extends ConsumerStatefulWidget {
  const GuestPreviewScreen({super.key});

  @override
  ConsumerState<GuestPreviewScreen> createState() => _GuestPreviewScreenState();
}

class _GuestPreviewScreenState extends ConsumerState<GuestPreviewScreen> {
  // File state
  File? _file;
  Uint8List? _fileBytes; // web only
  String? _fileName;
  String? _fileExt;
  String? _extractedText;
  int _wordCount = 0;

  // UI state
  _Step _step = _Step.upload;
  String _statusMessage = '';
  String? _errorMessage;
  _GuestResult? _result;
  bool _dragHover = false;

  @override
  void dispose() {
    super.dispose();
  }

  // ── File Picker ────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: kIsWeb,
      );
      if (result == null) return;

      final picked = result.files.single;
      final ext = (picked.extension ?? '').toLowerCase();

      if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
        _showSnack('Only PDF, JPG, PNG supported.');
        return;
      }

      if (kIsWeb) {
        final bytes = picked.bytes;
        if (bytes == null || bytes.isEmpty) {
          _showSnack('Could not read file. Try again.');
          return;
        }
        _applyPickedBytes(Uint8List.fromList(bytes), picked.name, ext);
      } else {
        if (picked.path == null) return;
        final file = File(picked.path!);
        if (!await file.exists()) {
          _showSnack('File not found. Try again.');
          return;
        }
        await _applyPickedFile(file, picked.name, ext);
      }
    } catch (_) {
      _showSnack('Could not open file. Try a different file.');
    }
  }

  /// Handles a file dropped directly onto the drop zone (web). Goes through
  /// the exact same validation and state-setting as browsing for a file, so
  /// drag-and-drop can never behave differently from tap-to-browse.
  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    final dropped = files.first;
    final ext = dropped.name.split('.').last.toLowerCase();
    if (!['pdf', 'jpg', 'jpeg', 'png'].contains(ext)) {
      _showSnack('Only PDF, JPG, PNG supported.');
      return;
    }
    try {
      final bytes = await dropped.readAsBytes();
      if (bytes.isEmpty) {
        _showSnack('Could not read file. Try again.');
        return;
      }
      _applyPickedBytes(bytes, dropped.name, ext);
    } catch (_) {
      _showSnack('Could not open file. Try a different file.');
    }
  }

  void _applyPickedBytes(Uint8List bytes, String name, String ext) {
    if (bytes.length > 10 * 1024 * 1024) {
      _showSnack('File too large (max 10 MB).');
      return;
    }
    setState(() {
      _fileBytes = bytes;
      _fileName = name;
      _fileExt = ext;
      _file = null;
      _extractedText = null;
      _result = null;
      _step = _Step.upload;
    });
  }

  Future<void> _applyPickedFile(File file, String name, String ext) async {
    final size = await file.length();
    if (size == 0) {
      _showSnack('File is empty.');
      return;
    }
    if (size > 10 * 1024 * 1024) {
      _showSnack('File too large (max 10 MB).');
      return;
    }
    setState(() {
      _file = file;
      _fileName = name;
      _fileExt = ext;
      _fileBytes = null;
      _extractedText = null;
      _result = null;
      _step = _Step.upload;
    });
  }

  bool get _hasFile => _file != null || _fileBytes != null;

  void _removeFile() => setState(() {
    _file = null;
    _fileBytes = null;
    _fileName = null;
    _fileExt = null;
    _extractedText = null;
    _result = null;
    _step = _Step.upload;
  });

  // ── Analysis Pipeline ──────────────────────────────────────────────────────

  Future<void> _runAnalysis() async {
    if (!_hasFile) {
      _showSnack('Please select a resume file first.');
      return;
    }

    setState(() {
      _step = _Step.analyzing;
      _statusMessage = 'Reading your resume...';
      _errorMessage = null;
    });

    try {
      // Step 1: Extract text
      final ocrService = ref.read(ocrServiceProvider);
      OcrResult ocrResult;

      if (kIsWeb && _fileBytes != null) {
        ocrResult = await ocrService.extractTextFromBytes(
          bytes: _fileBytes!,
          extension: _fileExt ?? 'pdf',
        );
      } else {
        ocrResult = await ocrService.extractText(_file!);
      }

      final text = ocrResult.text.trim();
      if (text.length < 80) {
        setState(() {
          _step = _Step.error;
          _errorMessage =
              'Could not extract enough text from this file.\n\n'
              'Make sure your PDF has actual text (not a scanned image) '
              'or try a clearer JPG/PNG.';
        });
        return;
      }

      setState(() {
        _extractedText = text;
        _wordCount = text.split(RegExp(r'\s+')).length;
        _statusMessage = 'AI is analyzing your resume...';
      });

      // Step 2: Run the canonical ATS analysis
      final result = await _callGuestAnalysis(text);

      setState(() {
        _result = result;
        _step = _Step.result;
      });
    } catch (e) {
      setState(() {
        _step = _Step.error;
        _errorMessage =
            'Something went wrong: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  /// Runs the resume through the exact same canonical ATS analysis the main
  /// ATS Checker screen uses (AiService.analyzeAtsOnly) — same prompt, same
  /// model, same scoring rubric. This is what makes the guest score and the
  /// signed-in score agree for the same resume, instead of drifting apart
  /// like they did when this screen had its own separate prompt. No
  /// Firestore save happens here since guests aren't authenticated — we
  /// just read the fields off the returned AnalysisModel.
  Future<_GuestResult> _callGuestAnalysis(String resumeText) async {
    final aiService = ref.read(aiServiceProvider);
    final model = await aiService.analyzeAtsOnly(
      resumeText: resumeText,
      userId: 'guest',
      resumeId: 'guest-preview-${DateTime.now().millisecondsSinceEpoch}',
    );

    if (model.finalRecommendation == 'Not a Resume') {
      throw Exception(
        'This doesn\'t look like a resume. Please upload an actual resume/CV file.',
      );
    }

    final findings = <String>[
      ...model.weaknesses.take(2),
      if (model.strengths.isNotEmpty) model.strengths.first,
    ].take(3).toList();

    return _GuestResult(
      atsScore: model.atsScore,
      overallAssessment: model.finalRecommendation,
      quickFindings: findings.isEmpty
          ? ['Full breakdown ready — sign up to see everything we found.']
          : findings,
      criticalIssuesCount: model.weaknesses.length,
      missingKeywords: model.missingSkills,
      strengthAreas: model.strengths,
      redFlags: model.weaknesses,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) return AppTheme.success;
    if (score >= 55) return AppTheme.warning;
    return AppTheme.error;
  }

  String _scoreLabel(int score) {
    if (score >= 75)
      return '✅  Good baseline — unlock full report to push it higher';
    if (score >= 55)
      return '⚠️  Needs work — you\'re missing key opportunities';
    return '❌  High rejection risk — several critical issues found';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Free ATS Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (_step) {
            _Step.upload => _buildUploadStep(),
            _Step.analyzing => _buildAnalyzingStep(),
            _Step.result => _buildResultStep(),
            _Step.error => _buildErrorStep(),
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 1 — Upload
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildUploadStep() => SingleChildScrollView(
    key: const ValueKey('upload'),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No account needed',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Upload your resume PDF or image and get a real AI-powered ATS score in seconds — free.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Step 1: Upload file
        _stepHeader(1, 'Upload your resume', 'PDF, JPG, or PNG — max 10 MB'),
        const SizedBox(height: 12),
        _hasFile ? _filePreviewTile() : _dropZone(),

        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.lock_outline, size: 11, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Your resume is not stored or shared without an account.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Analyze button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _hasFile ? _runAnalysis : null,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text(
              'Get My Free ATS Score',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.primary.withOpacity(0.35),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        if (!_hasFile) ...[
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Select a file above to enable analysis',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],

        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              'Already have an account? Sign in →',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    ),
  );

  Widget _stepHeader(int n, String title, String sub) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$n',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Text(
            sub,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    ],
  );

  Widget _dropZone() {
    final zone = GestureDetector(
      onTap: _pickFile,
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(12),
        color: _dragHover
            ? AppTheme.primary
            : AppTheme.primary.withOpacity(0.45),
        strokeWidth: _dragHover ? 2.2 : 1.5,
        dashPattern: const [8, 4],
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: _dragHover
                ? AppTheme.primary.withOpacity(0.08)
                : AppTheme.primary.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _dragHover
                      ? Icons.file_download_outlined
                      : Icons.upload_file_outlined,
                  size: 28,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _dragHover
                    ? 'Drop to upload'
                    : kIsWeb
                    ? 'Tap to browse, or drag a file here'
                    : 'Tap to select your resume',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF · JPG · PNG',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );

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

  Widget _filePreviewTile() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppTheme.success.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.success.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(
          _fileExt == 'pdf'
              ? Icons.picture_as_pdf_outlined
              : Icons.image_outlined,
          color: AppTheme.success,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fileName ?? 'resume',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Ready to analyze',
                style: TextStyle(fontSize: 11, color: AppTheme.success),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _removeFile,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
          ),
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 2 — Analyzing
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAnalyzingStep() => Center(
    key: const ValueKey('analyzing'),
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Analyzing Your Resume',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            _statusMessage,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'This usually takes 5–10 seconds.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 3 — Result
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildResultStep() {
    final r = _result!;
    final color = _scoreColor(r.atsScore);

    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Score Card ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Your ATS Score',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                // Score + ring visual — animates in from 0
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: r.atsScore / 100),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            r.atsScore >= 75
                                ? const Color(0xFF00C49A)
                                : Colors.white,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${(value * 100).round()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const Text(
                            '/ 100',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Assessment line
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.overallAssessment,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _scoreLabel(r.atsScore),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── File info pill ─────────────────────────────────────────────
          if (_wordCount > 0)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.subtleFill(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '📄  $_fileName  ·  $_wordCount words extracted',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ── Quick Findings (visible) ───────────────────────────────────
          _sectionTitle('🔍  What We Found'),
          const SizedBox(height: 10),
          ...r.quickFindings.asMap().entries.map(
            (e) => _FindingTile(number: e.key + 1, text: e.value),
          ),

          const SizedBox(height: 20),

          // ── Critical Issues count (visible, details locked) ────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: r.criticalIssuesCount >= 7
                  ? AppTheme.error.withOpacity(0.06)
                  : AppTheme.warning.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: r.criticalIssuesCount >= 7
                    ? AppTheme.error.withOpacity(0.25)
                    : AppTheme.warning.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Text(
                  r.criticalIssuesCount >= 7 ? '🚨' : '⚠️',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.criticalIssuesCount} critical issues found',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Create a free account to see every issue with fix suggestions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Locked: Missing Keywords ───────────────────────────────────
          _LockedSection(
            icon: '🔑',
            title: '${r.missingKeywords.length} Missing Keywords',
            subtitle: 'These keywords are hurting your ATS ranking',
            previewCount: r.missingKeywords.length,
            previewLabels: r.missingKeywords
                .map((k) => k[0])
                .toList(), // blur hint
          ),

          const SizedBox(height: 12),

          // ── Locked: Strengths ──────────────────────────────────────────
          _LockedSection(
            icon: '💪',
            title: '${r.strengthAreas.length} Strength Areas Identified',
            subtitle: 'What\'s actually working in your resume',
            previewCount: r.strengthAreas.length,
          ),

          const SizedBox(height: 12),

          // ── Locked: Red Flags ──────────────────────────────────────────
          _LockedSection(
            icon: '🚩',
            title: '${r.redFlags.length} Red Flags',
            subtitle: 'Issues that make recruiters skip your resume',
            previewCount: r.redFlags.length,
          ),

          const SizedBox(height: 28),

          // ── CTA ────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(
                  AppRoutes.register,
                  extra: {'resumeText': _extractedText ?? ''},
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Free Account — Unlock Full Report',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Free forever · No credit card · 30 seconds to sign up',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _step = _Step.upload;
                _result = null;
              }),
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Try a Different Resume'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.border(context)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // Step 4 — Error
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildErrorStep() => Padding(
    key: const ValueKey('error'),
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('😕', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 18),
        const Text(
          'Analysis Failed',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          _errorMessage ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => setState(() {
              _step = _Step.upload;
              _errorMessage = null;
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FindingTile extends StatelessWidget {
  final int number;
  final String text;
  const _FindingTile({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.cardBg(context),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border(context)),
      boxShadow: AppTheme.elevation(context, strength: 0.4),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LockedSection extends StatelessWidget {
  final String icon, title, subtitle;
  final int previewCount;
  final List<String>? previewLabels;

  const _LockedSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.previewCount,
    this.previewLabels,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Stack(
      children: [
        // Content underneath
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fake blurred rows
              ...List.generate(
                previewCount.clamp(2, 4),
                (i) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  width: i % 2 == 0 ? double.infinity : 180,
                ),
              ),
            ],
          ),
        ),
        // Frosted lock overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
