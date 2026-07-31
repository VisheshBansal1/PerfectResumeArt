import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/jd_match_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../providers/resume_context_provider.dart';
import '../../premium/screens/jd_optimize_screen.dart';
import '../widgets/local_scan_widgets.dart';
import '../widgets/loaded_resume_card.dart';
import '../widgets/next_steps_cta.dart';
import '../widgets/resume_input_panel.dart';

/// Free, instant, unlimited-use keyword match between the user's resume and
/// any pasted job posting. 100% on-device — no AI call, no cost, no cap on
/// how many times someone can use it. This is deliberately the "free first
/// step"; the AI-powered rewrite lives behind the paid Job Description
/// Match tool (JdOptimizeScreen), which this screen funnels into.
class JdKeywordMatchScreen extends ConsumerStatefulWidget {
  const JdKeywordMatchScreen({super.key});

  @override
  ConsumerState<JdKeywordMatchScreen> createState() => _JdKeywordMatchScreenState();
}

class _JdKeywordMatchScreenState extends ConsumerState<JdKeywordMatchScreen> {
  final TextEditingController _jdController = TextEditingController();
  ResumeInputResult? _uploadedResume;
  JdMatchResult? _result;
  bool _changingResume = false;

  @override
  void dispose() {
    _jdController.dispose();
    super.dispose();
  }

  String _resolvedResumeText(ResumeContext ctx) {
    if (ctx.hasResume) return ctx.text;
    return _uploadedResume?.text ?? '';
  }

  void _checkMatch(ResumeContext ctx) {
    final resumeText = _resolvedResumeText(ctx);
    if (resumeText.trim().length < 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your resume text first — paste it below, or load one from the ATS Checker.'),
        ),
      );
      return;
    }
    if (_jdController.text.trim().length < 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a fuller job description — a line or two is too short to compare.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final result = JdMatchService.match(resumeText, _jdController.text);
    setState(() => _result = result);
    AnalyticsService().toolUsed('jd_keyword_match');
  }

  void _shareResult() {
    final r = _result;
    if (r == null) return;
    Share.share(
      'I checked my resume against a job description with Perfect Resume Art and scored '
      '${r.matchPercent}% keyword match — free, instant, no signup needed for the first look. '
      'Worth checking yours before you apply.',
    );
  }

  void _openJdOptimize(ResumeContext ctx, UserModel? user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JdOptimizeScreen(
          resumeText: _resolvedResumeText(ctx),
          userName: user?.name ?? '',
          userEmail: user?.email ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(resumeContextProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.maybeWhen(data: (u) => u, orElse: () => null);

    return Scaffold(
      appBar: AppBar(title: const Text('JD Keyword Match')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildIntro(),
            const SizedBox(height: 24),
            const Text('1. Your resume', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _buildResumeSource(ctx),
            const SizedBox(height: 22),
            const Text('2. Paste the job description', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _buildJdInput(),
            const SizedBox(height: 20),
            _buildCheckButton(ctx),
            if (_result != null) ...[
              const SizedBox(height: 28),
              _buildResults(_result!, ctx, user),
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
        colors: [AppTheme.primary, AppTheme.primaryDark],
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
          child: const Icon(Icons.manage_search, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JD Keyword Match',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'See exactly which keywords a job posting expects — and which ones you\'re missing',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildIntro() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Most ATS software ranks candidates by how many keywords from the job posting show up '
            'in the resume. Paste any job description below — from anywhere — and see your match '
            'instantly. Free and unlimited, no AI call needed.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _buildResumeSource(ResumeContext ctx) {
    final showPanel = !ctx.hasResume || _changingResume;
    if (!showPanel) {
      return LoadedResumeCard(
        onChangeRequested: () => setState(() => _changingResume = true),
        onRemoved: () => setState(() => _uploadedResume = null),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResumeInputPanel(
          accentColor: AppTheme.primary,
          source: 'jd_match',
          onResumeReady: (result) => setState(() {
            _uploadedResume = result;
            _changingResume = false;
          }),
          onCleared: () => setState(() => _uploadedResume = null),
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
    );
  }

  Widget _buildJdInput() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextField(
      controller: _jdController,
      maxLines: 10,
      minLines: 6,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(14),
        hintText: 'Paste the full job posting here — from LinkedIn, a company site, anywhere. '
            'The more complete it is, the more accurate your match score.',
        hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
      ),
    ),
  );

  Widget _buildCheckButton(ResumeContext ctx) => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () => _checkMatch(ctx),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const Icon(Icons.bolt_outlined),
      label: const Text('Check My Match', style: TextStyle(fontWeight: FontWeight.w700)),
    ),
  );

  Widget _buildResults(JdMatchResult result, ResumeContext ctx, UserModel? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              ScoreRing(score: result.matchPercent, size: 84, caption: 'Match'),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.verdict,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${result.matched.length} of ${result.totalKeywords} keywords found in your resume',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _shareResult,
                      icon: const Icon(Icons.ios_share, size: 15),
                      label: const Text('Share', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (result.missingCritical.isNotEmpty) ...[
          _KeywordGroup(
            title: 'Add these first — core requirements',
            subtitle: 'Explicitly called for in the posting and missing from your resume',
            color: AppTheme.error,
            keywords: result.missingCritical,
          ),
          const SizedBox(height: 16),
        ],
        if (result.missingNiceToHave.isNotEmpty) ...[
          _KeywordGroup(
            title: 'Nice to have',
            subtitle: 'Would strengthen your match, not deal-breakers',
            color: AppTheme.warning,
            keywords: result.missingNiceToHave,
          ),
          const SizedBox(height: 16),
        ],
        if (result.missingGeneral.isNotEmpty) ...[
          _KeywordGroup(
            title: 'Also mentioned in the posting',
            subtitle: 'Referenced but not flagged as a hard requirement',
            color: AppTheme.textSecondary,
            keywords: result.missingGeneral,
          ),
          const SizedBox(height: 16),
        ],
        if (result.matched.isNotEmpty) ...[
          _KeywordGroup(
            title: 'Already in your resume',
            subtitle: 'Nice — these are covered',
            color: AppTheme.success,
            keywords: result.matched,
          ),
          const SizedBox(height: 20),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _resolvedResumeText(ctx).trim().length >= 80 ? () => _openJdOptimize(ctx, user) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
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
                  child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Want these woven in for you?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Job Description Match rewrites your bullets to naturally include the missing keywords',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        NextStepsCta(resumeText: _resolvedResumeText(ctx)),
      ],
    );
  }
}

class _KeywordGroup extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<JdKeyword> keywords;

  const _KeywordGroup({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.keywords,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: keywords
              .map(
                (k) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    k.term,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
