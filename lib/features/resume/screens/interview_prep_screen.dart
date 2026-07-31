import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/interview_prep_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/resume_pdf_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../providers/premium_providers.dart';
import '../../../providers/resume_context_provider.dart';
import '../widgets/loaded_resume_card.dart';
import '../widgets/resume_input_panel.dart';

/// Free: paste a resume + a job description, get a full fit analysis and
/// 5 sample interview questions. Paid (₹39, one-time, unlocked forever for
/// this account — same model as Fix My Resume): the remaining ~15 questions
/// plus a downloadable PDF of the whole report.
class InterviewPrepScreen extends ConsumerStatefulWidget {
  const InterviewPrepScreen({super.key});

  @override
  ConsumerState<InterviewPrepScreen> createState() =>
      _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends ConsumerState<InterviewPrepScreen> {
  final _jdController = TextEditingController();
  ResumeInputResult? _currentInput;
  bool _changingResume = false;

  @override
  void dispose() {
    _jdController.dispose();
    super.dispose();
  }

  String get _resolvedResumeText {
    final fromInput = _currentInput?.text.trim() ?? '';
    if (fromInput.length > 50) return fromInput;
    return ref.read(resumeContextProvider).text;
  }

  Future<void> _runAnalysis() async {
    final resumeText = _resolvedResumeText;
    final jd = _jdController.text.trim();

    if (resumeText.trim().length < 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your resume first')),
      );
      return;
    }
    if (jd.length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste a fuller job description (50+ characters)'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(jobFitReportProvider.notifier)
        .analyze(resumeText: resumeText, jobDescription: jd);
  }

  Future<void> _handleUnlock({
    required String userEmail,
    required String userName,
  }) async {
    final paid = await PaywallSheet.show(
      context,
      plan: PaymentPlan.interviewPrep,
      userEmail: userEmail,
      userName: userName,
    );
    if (paid && mounted) {
      await ref.read(unlockProvider.notifier).unlock('interview_prep');
      await ref.read(jobFitReportProvider.notifier).unlockFullReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumeCtx = ref.watch(resumeContextProvider);
    final showPanel = !resumeCtx.hasResume || _changingResume;
    final state = ref.watch(jobFitReportProvider);
    final unlocked = ref.watch(unlockProvider).contains('interview_prep');
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.asData?.value;
    final userEmail = user?.email ?? '';
    final userName = user?.name ?? 'User';

    return Scaffold(
      appBar: AppBar(title: const Text('Job Fit + Interview Prep')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            const Text(
              'Your Resume',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (!showPanel)
              LoadedResumeCard(
                onChangeRequested: () => setState(() => _changingResume = true),
                onRemoved: () => setState(() => _currentInput = null),
              )
            else ...[
              ResumeInputPanel(
                accentColor: Colors.teal,
                source: 'interview_prep',
                onResumeReady: (result) => setState(() {
                  _currentInput = result;
                  _changingResume = false;
                }),
                onCleared: () => setState(() => _currentInput = null),
              ),
              if (resumeCtx.hasResume && _changingResume) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _changingResume = false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            const Text(
              'Job Description',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _buildJdInput(),
            const SizedBox(height: 20),
            _buildAnalyzeButton(state),
            if (state.error != null) _buildError(state.error!),
            if (state.report != null) ...[
              const SizedBox(height: 28),
              _buildResults(state, unlocked, userEmail, userName),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Input section ──────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0A0E1A), Color(0xFF1A1D27)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.record_voice_over,
                color: Colors.tealAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Job Fit + Interview Prep',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'See how well your resume fits a specific job, then walk in ready — tailored interview questions with model answers, free.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
      ],
    ),
  );

  Widget _buildJdInput() => Container(
    decoration: BoxDecoration(
      border: Border.all(color: AppTheme.borderLight),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextField(
      controller: _jdController,
      maxLines: 8,
      minLines: 5,
      decoration: const InputDecoration(
        hintText: 'Paste the full job description here...',
        contentPadding: EdgeInsets.all(14),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _buildAnalyzeButton(JobFitReportState state) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: state.isLoading ? null : _runAnalysis,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: state.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              state.report == null ? 'Analyze My Fit' : 'Re-Analyze',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
    ),
  );

  Widget _buildError(String message) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Results section ─────────────────────────────────────────────────────

  Widget _buildResults(
    JobFitReportState state,
    bool unlocked,
    String userEmail,
    String userName,
  ) {
    final report = state.report!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScoreHeader(report),
        const SizedBox(height: 10),
        _buildChecklistRow(),
        const SizedBox(height: 26),

        _sectionTitle('Summary'),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.recommendation.isNotEmpty) ...[
                Text(
                  report.recommendation,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                report.summary,
                style: const TextStyle(fontSize: 13.5, height: 1.5, color: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('ATS Report'),
        _buildAtsGrid(report.atsAnalysis),
        const SizedBox(height: 20),

        _sectionTitle('Skill Match'),
        _chipSection(
          report.skillsMatched,
          AppTheme.success,
          emptyText: 'No direct matches found.',
        ),
        const SizedBox(height: 20),

        _sectionTitle('Missing Skills'),
        _chipSection(
          report.skillsMissing,
          AppTheme.error,
          emptyText: 'No major gaps found.',
        ),
        if (report.topMissingKeywords.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Top missing keywords',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _chipSection(report.topMissingKeywords, AppTheme.warning),
        ],
        const SizedBox(height: 20),

        if (report.experienceMatch.isNotEmpty ||
            report.educationMatch.isNotEmpty ||
            report.projectAnalysis.isNotEmpty) ...[
          _sectionTitle('Experience, Education & Projects'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.experienceMatch.isNotEmpty)
                  _labeledLine('Experience', report.experienceMatch),
                if (report.educationMatch.isNotEmpty)
                  _labeledLine('Education', report.educationMatch),
                if (report.projectAnalysis.isNotEmpty)
                  _labeledLine('Projects', report.projectAnalysis),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        if (report.strengths.isNotEmpty || report.weaknesses.isNotEmpty) ...[
          _sectionTitle('Strengths & Weaknesses'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.strengths.isNotEmpty)
                Expanded(
                  child: _bulletCard(
                    'Strengths',
                    report.strengths,
                    AppTheme.success,
                  ),
                ),
              if (report.strengths.isNotEmpty && report.weaknesses.isNotEmpty)
                const SizedBox(width: 10),
              if (report.weaknesses.isNotEmpty)
                Expanded(
                  child: _bulletCard(
                    'Watch out for',
                    report.weaknesses,
                    AppTheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        _sectionTitle('Resume Improvements'),
        _bulletCard(null, report.resumeImprovements, AppTheme.accent),
        const SizedBox(height: 20),

        _sectionTitle('Selection Probability'),
        _card(
          child: Text(
            report.selectionProbability,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 30),

        Row(
          children: [
            const Text(
              'Interview Questions',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              report.isFullyUnlocked
                  ? '${report.interviewQuestions.length} questions'
                  : '${report.interviewQuestions.length} of 20',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...report.interviewQuestions.asMap().entries.map(
          (e) => _questionCard(e.key + 1, e.value),
        ),

        if (!report.isFullyUnlocked) ...[
          const SizedBox(height: 6),
          _buildLockedPreview(),
          const SizedBox(height: 16),
          _buildUnlockCard(state, userEmail, userName),
        ] else ...[
          const SizedBox(height: 10),
          if (report.finalRecruiterAdvice.isNotEmpty) ...[
            _sectionTitle('Final Recruiter Advice'),
            _card(
              color: AppTheme.primary.withOpacity(0.06),
              borderColor: AppTheme.primary.withOpacity(0.25),
              child: Text(
                report.finalRecruiterAdvice,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
          ],
          _buildDownloadButton(state, userName),
        ],

        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () {
              _jdController.clear();
              ref.read(jobFitReportProvider.notifier).reset();
            },
            child: const Text('Start a new analysis'),
          ),
        ),
      ],
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 65) return AppTheme.primary;
    if (score >= 50) return AppTheme.warning;
    return AppTheme.error;
  }

  Widget _buildScoreHeader(JobFitReport report) {
    final color = _scoreColor(report.overallScore);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${report.overallScore}',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 2),
                    child: Text(
                      '%',
                      style: TextStyle(fontSize: 18, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  report.matchLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.speed_rounded, color: color.withOpacity(0.5), size: 42),
        ],
      ),
    );
  }

  Widget _buildChecklistRow() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: const [
      _CheckChip('ATS Score'),
      _CheckChip('Skill Match'),
      _CheckChip('Missing Skills'),
      _CheckChip('Resume Improvements'),
      _CheckChip('Selection Probability'),
      _CheckChip('5 Interview Questions'),
    ],
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
    ),
  );

  Widget _card({required Widget child, Color? color, Color? borderColor}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color ?? AppTheme.surfaceLight,
          border: Border.all(color: borderColor ?? AppTheme.borderLight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );

  Widget _labeledLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textPrimary,
          height: 1.4,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );

  Widget _chipSection(List<String> items, Color color, {String? emptyText}) {
    if (items.isEmpty) {
      return Text(
        emptyText ?? '—',
        style: const TextStyle(
          fontSize: 12.5,
          color: AppTheme.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                s,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _bulletCard(String? title, List<String> items, Color dotColor) =>
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: dotColor,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (items.isEmpty)
              const Text(
                'None flagged.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildAtsGrid(InterviewPrepAtsAnalysis ats) => Row(
    children: [
      _statBox('ATS Score', ats.atsScore),
      const SizedBox(width: 8),
      _statBox('Keywords', ats.keywordCoverage),
      const SizedBox(width: 8),
      _statBox('Format', ats.formatScore),
      const SizedBox(width: 8),
      _statBox('Readability', ats.readabilityScore),
    ],
  );

  Widget _statBox(String label, int value) {
    final color = _scoreColor(value);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return AppTheme.success;
      case 'Hard':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  Widget _tag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _questionCard(int number, InterviewQA qa) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      border: Border.all(color: AppTheme.borderLight),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          'Q$number. ${qa.question}',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            children: [
              _tag(qa.category.label, AppTheme.primary),
              _tag(qa.difficulty, _difficultyColor(qa.difficulty)),
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              qa.answer,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildLockedPreview() => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Column(
            children: List.generate(
              3,
              (i) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      color: AppTheme.borderLight,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 180,
                      color: AppTheme.borderLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.4),
            ),
            alignment: Alignment.center,
            child: const Text(
              '+15 more questions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildUnlockCard(
    JobFitReportState state,
    String userEmail,
    String userName,
  ) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppTheme.primary.withOpacity(0.08),
          Colors.teal.withOpacity(0.08),
        ],
      ),
      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lock_outline, color: AppTheme.primary, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unlock Complete Interview Preparation',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Get all 20 questions across HR, Technical, Coding, Behavioural, Project & Resume-based rounds — plus a downloadable PDF report.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.isUnlocking
                ? null
                : () => _handleUnlock(userEmail: userEmail, userName: userName),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isUnlocking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Unlock for ₹39',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDownloadButton(JobFitReportState state, String userName) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: state.isGeneratingPdf
              ? null
              : () async {
                  await ref
                      .read(jobFitReportProvider.notifier)
                      .generatePdf(name: userName);
                  final path = ref.read(jobFitReportProvider).pdfPath;
                  if (path != null && mounted) {
                    ResumePdfService().sharePdf(
                      path,
                      subject: 'Interview Prep Report',
                    );
                  }
                },
          icon: state.isGeneratingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(
            state.isGeneratingPdf
                ? 'Preparing PDF...'
                : 'Download Full Report (PDF)',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppTheme.primary),
            foregroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
}

class _CheckChip extends StatelessWidget {
  final String label;
  const _CheckChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.success.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 13, color: AppTheme.success),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppTheme.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
