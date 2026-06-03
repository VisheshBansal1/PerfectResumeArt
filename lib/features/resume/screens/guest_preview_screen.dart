// lib/features/resume/screens/guest_preview_screen.dart
//
// COMPLETE REWRITE — now uses real PDF/image upload + real AI analysis
// (same OCR pipeline as main app, direct backend call, no Firebase save)
//
// Dependencies already in your pubspec: file_picker, dotted_border, http
// Providers used: ocrServiceProvider (no Firebase auth needed)

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/app_config.dart';
import '../../../core/services/ocr_service.dart';
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

  // Optional job input
  final _jobCtrl = TextEditingController();

  @override
  void dispose() {
    _jobCtrl.dispose();
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
        if (bytes.length > 10 * 1024 * 1024) {
          _showSnack('File too large (max 10 MB).');
          return;
        }
        setState(() {
          _fileBytes = Uint8List.fromList(bytes);
          _fileName = picked.name;
          _fileExt = ext;
          _file = null;
          _extractedText = null;
          _result = null;
          _step = _Step.upload;
        });
      } else {
        if (picked.path == null) return;
        final file = File(picked.path!);
        if (!await file.exists()) {
          _showSnack('File not found. Try again.');
          return;
        }
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
          _fileName = picked.name;
          _fileExt = ext;
          _fileBytes = null;
          _extractedText = null;
          _result = null;
          _step = _Step.upload;
        });
      }
    } catch (_) {
      _showSnack('Could not open file. Try a different file.');
    }
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

      // Step 2: Call backend AI
      final result = await _callGuestAnalysis(text, _jobCtrl.text.trim());

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

  Future<_GuestResult> _callGuestAnalysis(
    String resumeText,
    String jobTitle,
  ) async {
    // Truncate resume — keeps prompt well under backend's 5 MB body limit
    final safeText = resumeText.length > 8000
        ? resumeText.substring(0, 8000)
        : resumeText;

    final jobLine = jobTitle.isNotEmpty
        ? 'Target role: $jobTitle'
        : 'No specific role — do a general ATS/readability analysis';

    // ── Prompt ──────────────────────────────────────────────────────────────
    // Kept intentionally short so the model has maximum tokens for its output.
    // We ask for the JSON object to START immediately (no preamble).
    final prompt =
        '''
You are an ATS resume expert. Analyze the resume and respond with ONLY a valid JSON object — no markdown, no explanation, no text before or after the JSON.

$jobLine

Resume:
"""
$safeText
"""

Respond with exactly this JSON (fill every field, keep string values concise):
{"atsScore":0,"overallAssessment":"","quickFindings":["","",""],"criticalIssuesCount":0,"missingKeywords":["","","","",""],"strengthAreas":["","",""],"redFlags":["","",""]}

Rules:
- atsScore: 0-100 integer reflecting real ATS compatibility
- overallAssessment: one sentence, max 10 words
- quickFindings: 3 specific observations about THIS resume (reference actual content)
- criticalIssuesCount: total issues found (visible + locked)
- missingKeywords: 5 important missing keywords for the target role
- strengthAreas: 3 genuine positives in this resume
- redFlags: 3 issues that hurt ATS ranking
Output the completed JSON object immediately, starting with {''';

    // ── HTTP call ────────────────────────────────────────────────────────────
    final response = await http
        .post(
          Uri.parse('${AppConfig.backendUrl}/api/ai/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'prompt': prompt,
            'model': 'llama-3.1-8b-instant',
            'maxTokens': 1200, // was 800 — extra room prevents mid-JSON cutoff
          }),
        )
        .timeout(const Duration(seconds: 40));

    if (response.statusCode != 200) {
      final errBody = jsonDecode(response.body);
      final msg = errBody['error'] ?? 'HTTP ${response.statusCode}';
      throw Exception('Analysis service error: $msg');
    }

    // ── Parse response ───────────────────────────────────────────────────────
    final body = jsonDecode(response.body);

    // Backend may return { response: "..." } OR { content: "..." } OR { result: "..." }
    final rawText =
        (body['response'] ?? body['content'] ?? body['result'] ?? '')
            .toString()
            .trim();

    if (rawText.isEmpty) {
      throw Exception('Empty response from AI service. Please try again.');
    }

    // Extract the JSON object by brace matching — handles any preamble/postamble
    // the model might add despite instructions.
    final jsonStr = _extractJsonObject(rawText);
    if (jsonStr == null) {
      throw Exception(
        'Could not read the AI response. Please try again.\n\n'
        'Tip: if this keeps happening, try a shorter resume.',
      );
    }

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('Malformed analysis response. Please try again.');
    }

    return _GuestResult(
      atsScore: ((parsed['atsScore'] as num?)?.toInt() ?? 50).clamp(0, 100),
      overallAssessment:
          parsed['overallAssessment'] as String? ?? 'Analysis complete',
      quickFindings: _safeStringList(parsed['quickFindings']),
      criticalIssuesCount:
          (parsed['criticalIssuesCount'] as num?)?.toInt() ?? 0,
      missingKeywords: _safeStringList(parsed['missingKeywords']),
      strengthAreas: _safeStringList(parsed['strengthAreas']),
      redFlags: _safeStringList(parsed['redFlags']),
    );
  }

  /// Finds the first complete `{ ... }` block in [text] using brace counting.
  /// Returns null if no valid JSON object is found.
  String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    if (start == -1) return null;

    int depth = 0;
    bool inString = false;
    bool escape = false;

    for (int i = start; i < text.length; i++) {
      final ch = text[i];

      if (escape) {
        escape = false;
        continue;
      }
      if (ch == r'\' && inString) {
        escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (ch == '{')
        depth++;
      else if (ch == '}') {
        depth--;
        if (depth == 0) {
          // Found the closing brace — return the complete object
          return text.substring(start, i + 1);
        }
      }
    }
    return null; // Truncated JSON — couldn't find matching }
  }

  /// Safely converts a dynamic list (or null) to List<String>.
  List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
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

        // Step 2: Job title (optional)
        const SizedBox(height: 24),
        _stepHeader(
          2,
          'What job are you targeting?',
          'Optional — improves accuracy',
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _jobCtrl,
          decoration: InputDecoration(
            hintText:
                'e.g. "Flutter Developer", "Data Analyst", "Backend Engineer"',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.55),
              fontSize: 13,
            ),
            prefixIcon: const Icon(Icons.work_outline, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
          ),
        ),

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

  Widget _dropZone() => GestureDetector(
    onTap: _pickFile,
    child: DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      color: AppTheme.primary.withOpacity(0.45),
      strokeWidth: 1.5,
      dashPattern: const [8, 4],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.03),
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
                Icons.upload_file_outlined,
                size: 28,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap to select your resume',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
                // Score + ring visual
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: r.atsScore / 100,
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
                          '${r.atsScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const Text(
                          '/ 100',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
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
                  color: Colors.grey[100],
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
                side: BorderSide(color: AppTheme.borderLight),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.borderLight),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
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
      border: Border.all(color: AppTheme.borderLight),
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
                    color: Colors.grey[200],
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
