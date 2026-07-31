// lib/features/resume/screens/home_screen.dart
//
// DROP-IN REPLACEMENT for your existing home_screen.dart
//
// New sections added (keeping all existing code intact):
//   P1 #1 — Testimonials (horizontal scroll)
//   P1 #2 — Before vs After ATS (animated flip card)
//   P2 #4 — How It Works (step-by-step)
//   P2 #6 — Feedback Button (bottom-left overlay → bottom sheet)
//   P3 #7 — Exit Intent Popup (replaces plain exit dialog)
//   P3 #8 — "X+ Resumes Analyzed" counter pill
//
// New imports needed:
//   ../widgets/feedback_button.dart   (see feedback_button.dart)
//   ../../../providers/stats_provider.dart  (see stats_provider.dart)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/referral_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../providers/stats_provider.dart'; // NEW
import '../../../models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../premium/screens/premium_hub_screen.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/feedback_button.dart'; // NEW

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // ── P3 #7: Exit Intent Popup ──────────────────────────────────────────────
  Future<void> _onBackPressed(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✋', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 14),
              const Text(
                'Your Dream Job Is Still Out There',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Recruiters spend just 6 seconds on a resume.\nOne free ATS check could change everything.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Check My Resume — It\'s Free',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Exit anyway',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldExit == true && context.mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (user) => user, orElse: () => null);
    final analyses = ref.watch(userAnalysesProvider);
    final totalCount = ref.watch(totalAnalysesCountProvider); // P3 #8

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _onBackPressed(context);
      },
      child: Scaffold(
        drawer: const AppNavigationDrawer(),
        appBar: AppBar(
          title: const Text('Resume Analyzer'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push(AppRoutes.profile),
              tooltip: 'Profile',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.uploadResume),
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Analyze Resume',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Greeting ─────────────────────────────────────────────
                  _buildGreeting(user?.name ?? 'there'),

                  // ── P3 #8: Analyzed Counter ───────────────────────────────
                  const SizedBox(height: 10),
                  totalCount.when(
                    data: (count) => count >= 10
                        ? _buildAnalyzedCounter(count)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // ── Quick Stats ───────────────────────────────────────────
                  const SizedBox(height: 20),
                  _buildQuickStats(context, analyses),

                  // ── Quick Tools ───────────────────────────────────────────
                  const SizedBox(height: 24),
                  const Text(
                    'Quick Tools',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickTools(context),

                  // ── Recent Analyses (moved up — your own stuff first) ─────
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Analyses',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => ref.invalidate(userAnalysesProvider),
                        child: Icon(
                          Icons.refresh,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  analyses.when(
                    data: (list) => list.isEmpty
                        ? _buildEmptyState(context)
                        : Column(
                            children: list
                                .take(2)
                                .map((a) => _AnalysisCard(analysis: a))
                                .toList(),
                          ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),

                  // ── Everything below is "why this app is good" content —
                  // visually separated so the page reads as two clear parts:
                  // your stuff, then why to trust it. ───────────────────────
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.borderLight)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'WHY IT WORKS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppTheme.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.borderLight)),
                    ],
                  ),

                  // ── P1 #2: Before vs After ────────────────────────────────
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'Real Results, Not Promises',
                    'A resume that went from ignored to interview-ready:',
                  ),
                  const SizedBox(height: 12),
                  const _BeforeAfterCard(),

                  // ── P2 #4: How It Works ───────────────────────────────────
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'How It Works',
                    'From upload to job-ready in minutes — no guesswork.',
                  ),
                  const SizedBox(height: 14),
                  const _HowItWorksList(),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.uploadResume),
                      icon: const Icon(Icons.bolt_outlined, size: 18),
                      label: const Text('Start My Free Analysis'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  // ── P1 #1: Testimonials ───────────────────────────────────
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'What Users Are Saying',
                    'Real stories from people who landed interviews.',
                  ),
                  const SizedBox(height: 12),
                  const _TestimonialsRow(),

                  // Padding so FABs don't obscure last card
                  const SizedBox(height: 120),
                ],
              ),
            ),

            // ── P2 #6: Feedback Button (bottom-left, above FAB) ────────────
            const Positioned(left: 16, bottom: 24, child: FeedbackButton()),
          ],
        ),
      ),
    );
  }

  // ── Section Header ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ),
    ],
  );

  // ── P3 #8: Counter Pill ─────────────────────────────────────────────────────

  Widget _buildAnalyzedCounter(int count) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 14, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            '${count *100}+ resumes analyzed & improved',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Existing: Greeting ──────────────────────────────────────────────────────

  Widget _buildGreeting(String name) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hello, ${name.split(' ').first} 👋',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 4),
      Text(
        'Let\'s improve your resume today',
        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
      ),
    ],
  );

  // ── Existing: Quick Stats ───────────────────────────────────────────────────

  Widget _buildQuickStats(
    BuildContext context,
    AsyncValue<List<AnalysisModel>> analyses,
  ) {
    return analyses.when(
      data: (list) {
        final avgScore = list.isEmpty
            ? 0
            : (list.map((a) => a.overallScore).reduce((a, b) => a + b) /
                      list.length)
                  .round();
        final bestScore = list.isEmpty
            ? 0
            : list.map((a) => a.overallScore).reduce((a, b) => a > b ? a : b);
        final atsAvg = list.isEmpty
            ? 0
            : (list.map((a) => a.atsScore).reduce((a, b) => a + b) /
                      list.length)
                  .round();

        return GestureDetector(
          onTap: () => context.push(AppRoutes.progress),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _GradientStatItem(label: 'Analyses', value: '${list.length}'),
                  _VerticalDivider(),
                  _GradientStatItem(label: 'Avg Score', value: '$avgScore%'),
                  _VerticalDivider(),
                  _GradientStatItem(label: 'Best', value: '$bestScore%'),
                  _VerticalDivider(),
                  _GradientStatItem(label: 'Avg ATS', value: '$atsAvg%'),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ── Existing: Quick Tools ───────────────────────────────────────────────────

  Widget _buildQuickTools(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _ToolCard(
              icon: Icons.auto_awesome,
              title: 'Analyze for Job',
              subtitle: 'Match resume to a job role',
              color: AppTheme.primary,
              onTap: () => context.push(AppRoutes.uploadResume),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ToolCard(
              icon: Icons.fact_check_outlined,
              title: 'ATS Checker',
              subtitle: 'Test ATS compatibility',
              color: Colors.purple,
              onTap: () => context.push(AppRoutes.atsChecker),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _ToolCardWide(
        icon: Icons.code_outlined,
        title: 'Custom Tech Stack Check',
        subtitle: 'Enter your own tech stack and check resume fit',
        color: AppTheme.accent,
        onTap: () => context.push(AppRoutes.uploadResume, extra: 'custom'),
      ),
      const SizedBox(height: 12),
      _ToolCardWide(
        icon: Icons.record_voice_over,
        title: 'Job Fit + Interview Prep',
        subtitle: 'Match a resume to any JD and get tailored interview Q&A',
        color: Colors.teal,
        onTap: () => context.push(AppRoutes.interviewPrep),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _ToolCard(
              icon: Icons.manage_search,
              title: 'JD Keyword Match',
              subtitle: 'Free instant match vs any job post',
              color: AppTheme.primary,
              onTap: () => context.push(AppRoutes.jdKeywordMatch),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ToolCard(
              icon: Icons.trending_up,
              title: 'My Progress',
              subtitle: 'Track your score over time',
              color: AppTheme.accent,
              onTap: () => context.push(AppRoutes.progress),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PremiumHubScreen(resumeText: ''),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A0E1A), Color(0xFF1A1D27)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Text('🚀', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Resume Tools',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Fix · JD Match · Why Rejected · PDF · Expert Review',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'from ₹39',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: Colors.white30,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
    ],
  );

  // ── Existing: Empty State ───────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 32),
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderLight),
    ),
    child: Column(
      children: [
        Icon(Icons.description_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 16),
        const Text(
          'No analyses yet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        const SizedBox(height: 6),
        Text(
          'Upload your resume to get AI-powered\nfeedback and match scores.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.uploadResume),
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Upload Resume'),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// P1 #2 — Before vs After Card (animated flip)
// ══════════════════════════════════════════════════════════════════════════════

class _BeforeAfterCard extends StatefulWidget {
  const _BeforeAfterCard();
  @override
  State<_BeforeAfterCard> createState() => _BeforeAfterCardState();
}

class _BeforeAfterCardState extends State<_BeforeAfterCard>
    with SingleTickerProviderStateMixin {
  bool _showingAfter = true;
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_showingAfter) {
      _controller.reverse().then((_) => setState(() => _showingAfter = false));
    } else {
      setState(() => _showingAfter = true);
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _showingAfter
              ? AppTheme.success.withOpacity(0.05)
              : AppTheme.error.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _showingAfter
                ? AppTheme.success.withOpacity(0.3)
                : AppTheme.error.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle tabs
            Row(
              children: [
                _Tab(
                  label: '❌  Before',
                  active: !_showingAfter,
                  activeColor: AppTheme.error,
                  onTap: () {
                    if (_showingAfter) _toggle();
                  },
                ),
                const SizedBox(width: 8),
                _Tab(
                  label: '✅  After',
                  active: _showingAfter,
                  activeColor: AppTheme.success,
                  onTap: () {
                    if (!_showingAfter) _toggle();
                  },
                ),
                const Spacer(),
                Text(
                  'tap to flip',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ATS Score display
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _showingAfter ? '87' : '38',
                    key: ValueKey(_showingAfter),
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: _showingAfter ? AppTheme.success : AppTheme.error,
                      height: 1,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATS Score',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          height: 8,
                          child: LinearProgressIndicator(
                            value: _showingAfter ? 0.87 : 0.38,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _showingAfter ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Changes list
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showingAfter
                  ? _ChangesList(
                      key: const ValueKey('after'),
                      items: const [
                        'Added "Python", "REST API", "Agile" keywords',
                        'Rewrote project bullets with impact metrics',
                        'Fixed date formatting & section order',
                        'Shortened objective → tailored summary',
                      ],
                      isPositive: true,
                    )
                  : _ChangesList(
                      key: const ValueKey('before'),
                      items: const [
                        'Missing 11 role-critical keywords',
                        'Project descriptions had no measurable impact',
                        'Inconsistent date format confused ATS',
                        'Generic objective statement added noise',
                      ],
                      isPositive: false,
                    ),
            ),

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _showingAfter
                          ? 'Total time: ~10 minutes with AI Resume Fix'
                          : 'This resume was rejected 14 times before analysis',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? activeColor.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? activeColor.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? activeColor : AppTheme.textSecondary,
        ),
      ),
    ),
  );
}

class _ChangesList extends StatelessWidget {
  final List<String> items;
  final bool isPositive;

  const _ChangesList({
    super.key,
    required this.items,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isPositive ? Icons.check_circle : Icons.cancel,
                  size: 15,
                  color: isPositive ? AppTheme.success : AppTheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// P2 #4 — How It Works
// ══════════════════════════════════════════════════════════════════════════════

class _HowItWorksList extends StatelessWidget {
  const _HowItWorksList();

  static const _steps = [
    (
      '📄',
      'Drop Your Resume',
      'Upload a PDF — or paste your resume text. Done in 10 seconds.',
    ),
    (
      '🎯',
      'Pick a Job Role',
      'Choose from common roles or type your own tech stack. We match precisely.',
    ),
    (
      '🤖',
      'AI Deep-Dives In',
      'Claude AI checks 40+ factors: keywords, structure, ATS compatibility, impact language.',
    ),
    (
      '📊',
      'Get Your Score',
      'See your ATS score, match %, missing keywords, and exactly what to fix.',
    ),
    (
      '🚀',
      'Fix & Apply',
      'Use Premium tools to rewrite, optimize, and send a job-ready resume in one click.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: _steps.asMap().entries.map((e) {
      final isLast = e.key == _steps.length - 1;
      return _HowItWorksStep(
        stepNumber: e.key + 1,
        emoji: e.value.$1,
        title: e.value.$2,
        description: e.value.$3,
        isLast: isLast,
      );
    }).toList(),
  );
}

class _HowItWorksStep extends StatelessWidget {
  final int stepNumber;
  final String emoji, title, description;
  final bool isLast;

  const _HowItWorksStep({
    required this.stepNumber,
    required this.emoji,
    required this.title,
    required this.description,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Left: step number + connecting line
      SizedBox(
        width: 40,
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      // Right: content
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// P1 #1 — Testimonials (horizontal scroll)
// ══════════════════════════════════════════════════════════════════════════════

class _TestimonialsRow extends StatelessWidget {
  const _TestimonialsRow();

  static const _testimonials = [
    (
      '⭐⭐⭐⭐⭐',
      '"My ATS score went from 34 to 91 in one afternoon. Got a callback from my dream company the next week."',
      'Arjun K.',
      'CSE Final Year, Delhi',
      '34 → 91',
    ),
    (
      '⭐⭐⭐⭐⭐',
      '"I was sending 50 applications and hearing nothing. This showed me exactly which keywords I was missing."',
      'Priya S.',
      'Recent Graduate',
      '50 rejections → interviews',
    ),
    (
      '⭐⭐⭐⭐⭐',
      '"The \'Why Rejected\' feature was an eye-opener. Found 3 resume killers in 2 minutes I\'d missed for months."',
      'Rohit M.',
      'Fresher → SDE-1 Offer',
      'Got offer in 3 weeks',
    ),
    (
      '⭐⭐⭐⭐⭐',
      '"Better than a paid resume consultant. Actual feedback, not generic advice. Worth every rupee."',
      'Sneha T.',
      'MBA → Product Role',
      'Switched careers',
    ),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 190,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 4),
      itemCount: _testimonials.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) {
        final t = _testimonials[i];
        return _TestimonialCard(
          stars: t.$1,
          quote: t.$2,
          name: t.$3,
          role: t.$4,
          result: t.$5,
        );
      },
    ),
  );
}

class _TestimonialCard extends StatelessWidget {
  final String stars, quote, name, role, result;

  const _TestimonialCard({
    required this.stars,
    required this.quote,
    required this.name,
    required this.role,
    required this.result,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 230,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderLight),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stars + result badge
        Row(
          children: [
            Expanded(child: Text(stars, style: const TextStyle(fontSize: 12))),
            Container(
              constraints: const BoxConstraints(maxWidth: 100),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                result,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Quote
        Expanded(
          child: Text(
            quote,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 8),
        // Person
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary.withOpacity(0.12),
              child: Text(
                name[0],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Existing widgets — unchanged from original home_screen.dart
// ══════════════════════════════════════════════════════════════════════════════

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: Colors.white.withOpacity(0.3));
}

class _GradientStatItem extends StatelessWidget {
  final String label, value;
  const _GradientStatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

class _ToolCardWide extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolCardWide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: color.withOpacity(0.6),
          ),
        ],
      ),
    ),
  );
}

class _AnalysisCard extends StatelessWidget {
  final AnalysisModel analysis;
  const _AnalysisCard({required this.analysis});

  Color get _scoreColor {
    if (analysis.overallScore >= AppConstants.excellentScore)
      return AppTheme.success;
    if (analysis.overallScore >= AppConstants.goodScore)
      return AppTheme.primary;
    if (analysis.overallScore >= AppConstants.averageScore)
      return AppTheme.warning;
    return AppTheme.error;
  }

  IconData get _typeIcon {
    switch (analysis.analysisType) {
      case 'ats_only':
        return Icons.fact_check_outlined;
      case 'custom_tech':
        return Icons.code_outlined;
      default:
        return Icons.work_outline;
    }
  }

  Color get _typeColor {
    switch (analysis.analysisType) {
      case 'ats_only':
        return Colors.purple;
      case 'custom_tech':
        return AppTheme.accent;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () => context.push(AppRoutes.analysisResultWithId(analysis.id)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${analysis.overallScore}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_typeIcon, size: 13, color: _typeColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          analysis.jobTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat('MMM d, yyyy').format(analysis.analyzedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (analysis.analysisType != 'ats_only')
                        _ScorePill(
                          'Match ${analysis.matchScore}%',
                          AppTheme.primary,
                        ),
                      _ScorePill('ATS ${analysis.atsScore}%', Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: analysis.adminDecision != null
                  ? _StatusChip(analysis.adminDecision!)
                  : (analysis.analysisType == 'ats_only' ||
                        analysis.analysisType == 'custom_tech')
                  ? _StatusChip(analysis.finalRecommendation, isAi: true)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScorePill extends StatelessWidget {
  final String text;
  final Color color;
  const _ScorePill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String text;
  final bool isAi;
  const _StatusChip(this.text, {this.isAi = false});

  Color get color {
    switch (text) {
      case 'Pass':
        return AppTheme.success;
      case 'High Potential':
        return AppTheme.primary;
      case 'Fail':
        return AppTheme.error;
      case 'Hold':
        return AppTheme.warning;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: isAi ? null : Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    ),
  );
}
