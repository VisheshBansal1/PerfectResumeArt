import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/services/app_config.dart';
import '../../../core/services/resume_improve_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../providers/premium_providers.dart';
import '../../../providers/resume_context_provider.dart';

// ─── Project Improver Screen ──────────────────────────────────────────────────

class ProjectImproverScreen extends ConsumerStatefulWidget {
  const ProjectImproverScreen({super.key});

  @override
  ConsumerState<ProjectImproverScreen> createState() =>
      _ProjectImproverScreenState();
}

class _ProjectImproverScreenState extends ConsumerState<ProjectImproverScreen> {
  final _lineCtrl = TextEditingController();
  final _contextCtrl = TextEditingController();

  @override
  void dispose() {
    _lineCtrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  void _improve() {
    if (_lineCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a project description first')),
      );
      return;
    }
    ref
        .read(projectImproveProvider.notifier)
        .improve(
          line: _lineCtrl.text.trim(),
          context: _contextCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectImproveProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Project Improver')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accent, const Color(0xFF00896C)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.rocket_launch, color: Colors.white, size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Improver',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '"Made a Flutter app" → Impressive engineer-level description',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Example hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.tips_and_updates,
                    color: AppTheme.warning,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Freshers: use this to make every project sound 10x better',
                      style: TextStyle(fontSize: 12, color: AppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Input
            const Text(
              'Your Project Line',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lineCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'e.g. "Made a Flutter app" or "Built a website for college project"',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Context (Optional)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contextCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText:
                    'e.g. "used Firebase and had 100 users" or "Final year project"',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: state.isLoading ? null : _improve,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text(
                  state.isLoading ? 'Improving…' : 'Improve This Line',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Result
            if (state.isLoading)
              const Center(child: CircularProgressIndicator()),
            if (state.error != null)
              Text(state.error!, style: const TextStyle(color: AppTheme.error)),
            if (state.result != null) _ProjectResult(result: state.result!),
          ],
        ),
      ),
    );
  }
}

class _ProjectResult extends StatelessWidget {
  final ImprovedProject result;
  const _ProjectResult({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Before vs After',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 12),
        // Before
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3F3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.close, color: AppTheme.error, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Before',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(result.original, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Icon(Icons.arrow_downward, color: Colors.grey, size: 18),
        ),
        const SizedBox(height: 8),
        // After
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FBF1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check, color: AppTheme.success, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'After',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                result.improved,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: result.improved));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
        if (result.tipsApplied.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Tips Applied:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...result.tipsApplied.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.success,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Selection Booster Screen ─────────────────────────────────────────────────

class SelectionBoosterScreen extends ConsumerStatefulWidget {
  final String resumeText;
  final String jobTitle;

  const SelectionBoosterScreen({
    super.key,
    this.resumeText = '',
    this.jobTitle = '',
  });

  @override
  ConsumerState<SelectionBoosterScreen> createState() =>
      _SelectionBoosterScreenState();
}

class _SelectionBoosterScreenState
    extends ConsumerState<SelectionBoosterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always prefer the live resume context over the passed-in text
      final ctx = ref.read(resumeContextProvider);
      final text = ctx.hasResume ? ctx.text : widget.resumeText;
      final role = widget.jobTitle.isNotEmpty
          ? widget.jobTitle
          : (ctx.detectedRole.isNotEmpty ? ctx.detectedRole : '');

      if (text.trim().length < 50) {
        // No resume — show error
        ref
            .read(selectionBoosterProvider.notifier)
            .setError('No resume detected. Please upload your resume first.');
        return;
      }

      ref
          .read(selectionBoosterProvider.notifier)
          .analyze(resumeText: text, jobTitle: role);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(selectionBoosterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add These to Get Selected')),
      body: state.isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_chart, size: 56, color: AppTheme.primary),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing what you need to add…',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            )
          : state.error != null
          ? Center(child: Text(state.error!))
          : state.result == null
          ? const SizedBox.shrink()
          : _BoosterResults(result: state.result!),
    );
  }
}

class _BoosterResults extends StatelessWidget {
  final SelectionBooster result;
  const _BoosterResults({required this.result});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D5BE3), Color(0xFF1A3DA8)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.priority_high, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      '#1 Priority Action',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.priorityAction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _BoosterSection(
            '📁 Projects to Add',
            result.projectsToAdd,
            const Color(0xFF7C3AED),
          ),
          _BoosterSection(
            '🛠 Skills to Add',
            result.skillsToAdd,
            AppTheme.accent,
          ),
          _BoosterSection(
            '📊 Metrics to Add',
            result.metricsToAdd,
            AppTheme.warning,
          ),
          _BoosterSection(
            '🔑 Keywords to Add',
            result.keywordsToAdd,
            AppTheme.primary,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _BoosterSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  const _BoosterSection(this.title, this.items, this.color);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 5, right: 10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─── Human Review Request Screen ──────────────────────────────────────────────

class HumanReviewScreen extends ConsumerStatefulWidget {
  final String userEmail;
  final String userName;

  const HumanReviewScreen({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  ConsumerState<HumanReviewScreen> createState() => _HumanReviewScreenState();
}

class _HumanReviewScreenState extends ConsumerState<HumanReviewScreen> {
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _uploadedFileName;
  String _resumeContent = '';

  // PDF bytes picked directly in this screen — takes priority over provider bytes.
  // Needed when user uploaded via ATS screen (which doesn't store bytes).
  Uint8List? _localPdfBytes;
  String? _localPdfName;

  final _notesCtrl      = TextEditingController();
  final _targetRoleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-load resume text from context
      final ctx = ref.read(resumeContextProvider);
      if (ctx.hasResume) {
        setState(() {
          _resumeContent = ctx.text;
          _uploadedFileName = 'Your uploaded resume (auto-detected)';
        });
      }
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _targetRoleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReviewRequest() async {
    if (_resumeContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please upload your resume first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? firestoreError;
    String? emailError;

    // ── Step 1: Save to Firestore ─────────────────────────────────────────────
    // Always save first — this is the permanent record of the request.
    // Even if email fails, admin can find the request in Firestore.
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final targetRole = _targetRoleCtrl.text.trim();
      final notes = _notesCtrl.text.trim();
      final slaDeadline = DateTime.now().add(const Duration(hours: 20));

      await FirebaseFirestore.instance.collection('human_review_requests').add({
        'userId': uid,
        'userName': widget.userName,
        'userEmail': widget.userEmail,
        'targetRole': targetRole,
        'additionalNotes': notes,
        'resumeText': _resumeContent,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'fileName': _uploadedFileName ?? 'resume',
        'slaDeadline': Timestamp.fromDate(slaDeadline),
        'reminderSent': false,
      });
    } catch (e) {
      // Firestore failed — stop here, don't show success
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: ${friendlyError(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    // ── Step 2: Send email via backend (PDF attached) ─────────────────────────
    // Firestore succeeded — now try to send the email.
    // Show a "sending email..." indicator so user knows it's working.
    try {
      final targetRole = _targetRoleCtrl.text.trim();
      final notes = _notesCtrl.text.trim();

      await _sendToBackend(
        userName:    widget.userName,
        userEmail:   widget.userEmail,
        targetRole:  targetRole,
        notes:       notes,
        resumeText:  _resumeContent,
      );
    } catch (e) {
      emailError = friendlyError(e);
    }

    // ── Step 3: Show result ───────────────────────────────────────────────────
    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _submitted = true; // Always mark submitted — Firestore record exists
      });

      if (emailError != null) {
        // Firestore saved but email failed — show warning, not full error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '⚠️ Request saved but email notification failed. '
              'Admin will still see your request in the system.',
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Request submitted! Admin notified with your resume.'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }


  /// Lets user pick a PDF specifically for the Human Review email attachment.
  /// Needed when resume was uploaded via ATS screen (bytes not in provider).
  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.bytes == null || file.bytes!.isEmpty) return;
      _applyPickedPdf(Uint8List.fromList(file.bytes!), file.name);
    } catch (e) {
      debugPrint('[HumanReview] PDF pick error: $e');
    }
  }

  /// Handles a PDF dropped directly onto the attach button (web) — goes
  /// through the exact same handling as the file picker.
  Future<void> _handleDroppedPdf(List<XFile> files) async {
    if (files.isEmpty) return;
    final dropped = files.first;
    if (!dropped.name.toLowerCase().endsWith('.pdf')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only PDF files are supported here.')),
        );
      }
      return;
    }
    try {
      final bytes = await dropped.readAsBytes();
      if (bytes.isEmpty) return;
      _applyPickedPdf(bytes, dropped.name);
    } catch (e) {
      debugPrint('[HumanReview] PDF drop error: $e');
    }
  }

  void _applyPickedPdf(Uint8List bytes, String name) {
    setState(() {
      _localPdfBytes = bytes;
      _localPdfName = name;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PDF selected: $name'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Wraps [child] so it also accepts a dragged-and-dropped PDF on web,
  /// without changing its appearance or the mobile tap-to-browse behavior.
  Widget _dragDropWrap(Widget child) {
    if (!kIsWeb) return child;
    return DropTarget(
      onDragDone: (details) async => _handleDroppedPdf(details.files),
      child: child,
    );
  }

  Future<void> _sendToBackend({
    required String userName,
    required String userEmail,
    required String targetRole,
    required String notes,
    required String resumeText,
  }) async {
    final backendUrl = AppConfig.backendUrl;
    final uri = Uri.parse('$backendUrl/api/human-review/submit');

    debugPrint('[HumanReview] POST $uri');

    try {
      final request = http.MultipartRequest('POST', uri);

      // ── Form fields ──────────────────────────────────────────────────────
      request.fields['userName']   = userName;
      request.fields['userEmail']  = userEmail;
      request.fields['targetRole'] = targetRole.isNotEmpty ? targetRole : 'Not specified';
      request.fields['notes']      = notes.isNotEmpty ? notes : 'None';
      // Include full resume text as backup (shown in email if PDF is missing)
      request.fields['resumeText'] = resumeText;

      // ── PDF attachment ────────────────────────────────────────────────────
      // Priority: 1) locally picked PDF in this screen
      //           2) bytes stored in provider (from Premium Hub upload)
      //           3) no PDF — text-only email
      final ctx        = ref.read(resumeContextProvider);
      final pdfBytes   = _localPdfBytes ?? (ctx.hasPdf ? ctx.pdfBytes : null);
      final pdfName    = _localPdfName  ?? (ctx.fileName.isNotEmpty ? ctx.fileName : 'resume.pdf');

      if (pdfBytes != null && pdfBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'resume',
            pdfBytes,
            filename:    pdfName,
            contentType: MediaType('application', 'pdf'),
          ),
        );
        debugPrint('[HumanReview] PDF attached: $pdfName (${pdfBytes.length} bytes)');
      } else {
        debugPrint('[HumanReview] No PDF bytes — sending text-only');
      }

      // ── Send request ─────────────────────────────────────────────────────
      final streamedResponse = await request
          .send()
          .timeout(const Duration(seconds: 30));

      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('[HumanReview] Response ${response.statusCode}: ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('[HumanReview] Backend error: ${response.body}');
        throw Exception('Email delivery failed (${response.statusCode})');
      }
    } on Exception {
      rethrow; // Let _submitReviewRequest handle and show the warning
    } catch (e) {
      debugPrint('[HumanReview] Backend call failed: $e');
      throw Exception(friendlyError(e));
    }
  }

  Future<void> _handlePurchaseAndSubmit() async {
    final unlocks = ref.read(unlockProvider);
    final isUnlocked =
        unlocks.contains('human_review') || unlocks.contains('bundle');

    if (!isUnlocked) {
      // A real person manually reviews and rewrites the resume for this
      // plan, so it's excluded from the rewarded-ad path — only a genuine
      // purchase can unlock it.
      final result = await PaywallSheet.show(
        context,
        plan: PaymentPlan.humanReview,
        userEmail: widget.userEmail,
        userName: widget.userName,
        allowAdUnlock: false,
      );
      if (result != PaywallResult.purchased || !mounted) return;
      await ref.read(unlockProvider.notifier).unlock('human_review');
    }

    if (mounted) await _submitReviewRequest();
  }

  @override
  Widget build(BuildContext context) {
    final unlocks = ref.watch(unlockProvider);
    final isUnlocked =
        unlocks.contains('human_review') || unlocks.contains('bundle');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Expert Human Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.textPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.person_search,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Real Human. Expert Writer.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A real person personally reads and rewrites your resume.\nDelivered to your email within 24 hours.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // What you get
            const Text(
              'What you get:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            ...[
              ('👤', 'Real Expert', '5+ years experience writing tech resumes'),
              (
                '⏱️',
                'Delivered in 24 Hours',
                'Improved resume sent to your email by tomorrow',
              ),
              (
                '✏️',
                'Full Rewrite',
                'Every section improved — bullets, summary, skills',
              ),
              ('💬', 'Written Feedback', 'Explanation of every change made'),
              (
                '🔄',
                'One Free Revision',
                'Not happy? One free change round included',
              ),
              (
                '🎯',
                'Bonus: LinkedIn Tips',
                'Headline + About section suggestion',
              ),
            ].map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            item.$3,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_submitted) ...[
              // ── SUCCESS STATE ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.success,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Request Submitted! ✅',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Our expert has received your resume. The improved version will be sent to ${widget.userEmail} within 24 hours.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppTheme.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Check your email inbox (and spam folder) tomorrow. If you don\'t receive it, contact support.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // ── UPLOAD / FORM STATE ────────────────────────────────────────

              // Resume upload section
              const Text(
                'Step 1: Your Resume',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: () async {
                  // Use resume from context if available
                  final ctx = ref.read(resumeContextProvider);
                  if (ctx.hasResume && _resumeContent == ctx.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Using your already-uploaded resume!'),
                      ),
                    );
                    return;
                  }
                  // Navigate user to upload screen if no resume
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please upload your resume from the Home screen first',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _uploadedFileName != null
                        ? AppTheme.success.withOpacity(0.06)
                        : (isDark
                              ? const Color(0xFF1A1D27)
                              : const Color(0xFFF9FAFB)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _uploadedFileName != null
                          ? AppTheme.success.withOpacity(0.4)
                          : (isDark ? Colors.white24 : const Color(0xFFE5E7EB)),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _uploadedFileName != null
                            ? Icons.check_circle
                            : Icons.upload_file,
                        color: _uploadedFileName != null
                            ? AppTheme.success
                            : AppTheme.textSecondary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _uploadedFileName ??
                                  'Tap to use your uploaded resume',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _uploadedFileName != null
                                    ? AppTheme.success
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            if (_uploadedFileName == null)
                              const Text(
                                '(Upload your resume from Home screen first)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // PDF attach — Step 1.5 between resume display and role
              _dragDropWrap(
                _PdfAttachButton(
                  localPdfName: _localPdfName,
                  hasPdfInProvider: ref.watch(resumeContextProvider).hasPdf,
                  onTap: _pickPdf,
                ),
              ),
              const SizedBox(height: 16),

              // Target role
              const Text(
                'Step 2: What role are you applying for?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _targetRoleCtrl,
                decoration: InputDecoration(
                  hintText:
                      'e.g. Flutter Developer, Data Analyst, Product Manager',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Additional notes
              const Text(
                'Step 3: Anything specific to improve? (Optional)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'e.g. "Make it better for startups" or "I have a gap year, please handle that"',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Price card
              if (!isUnlocked) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1D27) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Expert Human Review\n(One-time, includes 1 revision)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        PaymentPlan.humanReview.displayPrice,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handlePurchaseAndSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isUnlocked ? Icons.send_rounded : Icons.person_search,
                          size: 20,
                        ),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting...'
                        : isUnlocked
                        ? 'Submit My Resume for Review'
                        : 'Pay & Submit · ${PaymentPlan.humanReview.displayPrice}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textPrimary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  '🔒 Your resume is kept confidential and only seen by our expert',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}


// ── PDF Attach Button for Human Review ───────────────────────────────────────

class _PdfAttachButton extends StatelessWidget {
  final String? localPdfName;
  final bool hasPdfInProvider;
  final VoidCallback onTap;

  const _PdfAttachButton({
    required this.localPdfName,
    required this.hasPdfInProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAnyPdf = localPdfName != null || hasPdfInProvider;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasAnyPdf
              ? AppTheme.success.withOpacity(0.08)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasAnyPdf
                ? AppTheme.success.withOpacity(0.4)
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasAnyPdf ? Icons.picture_as_pdf : Icons.attach_file,
              color: hasAnyPdf ? AppTheme.success : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasAnyPdf ? 'PDF Ready to Send' : 'Attach Your Resume PDF',
                    style: TextStyle(
                      color: hasAnyPdf ? AppTheme.success : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    localPdfName != null
                        ? localPdfName!
                        : hasPdfInProvider
                            ? 'Using your uploaded resume'
                            : 'Tap to attach PDF — admin will receive it by email',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              hasAnyPdf ? Icons.check_circle : Icons.upload_file,
              color: hasAnyPdf ? AppTheme.success : Colors.white30,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}