import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/local_resume_analyzer.dart';
import '../../../providers/providers.dart';
import '../../../providers/resume_context_provider.dart';
import '../widgets/loaded_resume_card.dart';
import '../widgets/local_scan_widgets.dart';
import '../widgets/next_steps_cta.dart';
import '../widgets/resume_input_panel.dart';

class AtsCheckerScreen extends ConsumerStatefulWidget {
  const AtsCheckerScreen({super.key});

  @override
  ConsumerState<AtsCheckerScreen> createState() => _AtsCheckerScreenState();
}

class _AtsCheckerScreenState extends ConsumerState<AtsCheckerScreen> {
  ResumeInputResult? _currentInput;
  bool _changingResume = false;

  Future<void> _runAtsCheck() async {
    final input = _currentInput;
    String? analysisId;

    if (input != null && input.isFromFile && input.bytes != null) {
      // Real file this session — use it directly (accurate file name/type in metadata)
      analysisId = await ref.read(resumeUploadProvider.notifier).uploadAndAnalyzeAtsFromBytes(
            bytes: input.bytes!,
            fileName: input.fileName ?? 'resume',
            extension: input.extension ?? 'pdf',
          );
    } else {
      // Pasted text, or a resume already sitting in the shared context from another
      // screen — same canonical AiService.analyzeAtsOnly call either way.
      final ctx = ref.read(resumeContextProvider);
      if (!ctx.hasResume) return;
      analysisId = await ref.read(resumeUploadProvider.notifier).uploadAndAnalyzeAtsFromText(ctx.text);
    }

    if (analysisId != null && mounted) {
      ref.invalidate(userAnalysesProvider);
      context.go(AppRoutes.analysisResultWithId(analysisId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(resumeUploadProvider);
    final ctx = ref.watch(resumeContextProvider);
    final scanText = (uploadState.extractedText?.isNotEmpty ?? false)
        ? uploadState.extractedText!
        : ctx.text;
    final showPanel = !ctx.hasResume || _changingResume;

    return Scaffold(
      appBar: AppBar(title: const Text('ATS Checker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildWhatIsAts(),
            const SizedBox(height: 24),
            _buildInstantScanSection(scanText),
            const SizedBox(height: 20),
            _buildJdMatchCta(),
            const SizedBox(height: 28),
            const Text('Your Resume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (!showPanel)
              LoadedResumeCard(
                onChangeRequested: () => setState(() => _changingResume = true),
                onRemoved: () => setState(() => _currentInput = null),
              )
            else ...[
              ResumeInputPanel(
                accentColor: Colors.purple,
                source: 'ats',
                onResumeReady: (result) => setState(() {
                  _currentInput = result;
                  _changingResume = false;
                }),
                onCleared: () => setState(() => _currentInput = null),
              ),
              if (ctx.hasResume && _changingResume) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _changingResume = false),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            _buildRunButton(uploadState, ctx),
            if (uploadState.error != null) _buildError(uploadState.error!),
            if (scanText.trim().length >= 80) ...[
              const SizedBox(height: 32),
              NextStepsCta(resumeText: scanText),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.purple, Colors.purple.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ATS Compatibility Checker',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Test if your resume passes Applicant Tracking Systems',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildWhatIsAts() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.purple.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.purple.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.purple, size: 18),
            const SizedBox(width: 8),
            const Text('What is ATS?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'ATS (Applicant Tracking System) is software recruiters use to automatically filter resumes. '
          '75% of resumes are rejected by ATS before a human ever reads them. '
          'Our checker evaluates your resume\'s formatting, keywords, and structure.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
        ),
      ],
    ),
  );

  /// The real, computed, free Instant Health Scan. Runs the exact same
  /// LocalResumeAnalyzer used everywhere else resume text shows up, so this
  /// number never disagrees with itself across screens.
  Widget _buildInstantScanSection(String scanText) {
    if (scanText.trim().length < 30) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.purple.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_outlined, color: Colors.purple, size: 18),
                const SizedBox(width: 8),
                const Text('Instant Health Scan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'FREE',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '13 real checks — contact info, section headers, action verbs, quantified impact, '
              'parseability, and more — computed instantly on your device the moment you add a resume '
              'below. No AI call, no waiting, unlimited use.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
      );
    }

    final result = LocalResumeAnalyzer.analyze(scanText);
    return LocalScanReport(result: result);
  }

  Widget _buildJdMatchCta() => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => context.push(AppRoutes.jdKeywordMatch),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.manage_search, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Have a specific job in mind?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'Paste any job description — free instant keyword match, no AI needed',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
        ],
      ),
    ),
  );

  Widget _buildRunButton(ResumeUploadState uploadState, ResumeContext ctx) {
    final hasFile = _currentInput != null;
    final canRun = (hasFile || ctx.hasResume) && !uploadState.isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canRun ? _runAtsCheck : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: uploadState.isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.psychology_alt_outlined),
        label: Text(
          uploadState.isExtracting
              ? 'Reading resume...'
              : uploadState.isUploading
                  ? 'Uploading...'
                  : uploadState.isAnalyzing
                      ? 'Running deep AI check...'
                      : ctx.hasResume && !hasFile
                          ? 'Run Deep AI Check on Your Resume'
                          : 'Run Deep AI Check',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildError(String error) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(error, style: TextStyle(color: AppTheme.error, fontSize: 13)),
  );
}
