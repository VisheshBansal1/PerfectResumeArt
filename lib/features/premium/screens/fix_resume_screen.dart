import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_hire/core/services/resume_improve_service.dart';
import 'package:next_hire/features/premium/widgets/preminum_shared_widget.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/resume_pdf_service.dart';
import '../../../providers/premium_providers.dart';
import '../../../providers/resume_context_provider.dart';
import '../widgets/share_result_card.dart';

class FixResumeScreen extends ConsumerStatefulWidget {
  final String resumeText;
  final String userName;
  final String userEmail;

  const FixResumeScreen({
    super.key,
    required this.resumeText,
    required this.userName,
    required this.userEmail,
  });

  @override
  ConsumerState<FixResumeScreen> createState() => _FixResumeScreenState();
}

class _FixResumeScreenState extends ConsumerState<FixResumeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _unlocked = false;

  String get _effectiveResumeText {
    if (widget.resumeText.trim().length > 50) return widget.resumeText;
    // Fall back to global context if no text passed directly
    return ref.read(resumeContextProvider).text;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final unlocks = ref.read(unlockProvider);
      if (unlocks.contains('fix_resume')) {
        setState(() => _unlocked = true);
        _startFix();
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _startFix() {
    ref
        .read(fixResumeProvider.notifier)
        .fix(resumeText: _effectiveResumeText, jobTitle: '');
  }

  Future<void> _handleUnlock() async {
    final paid = await PaywallSheet.show(
      context,
      plan: PaymentPlan.fixResume,
      userEmail: widget.userEmail,
      userName: widget.userName,
    );
    if (paid && mounted) {
      await ref.read(unlockProvider.notifier).unlock('fix_resume');
      setState(() => _unlocked = true);
      _startFix();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fixResumeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix My Resume'),
        actions: [
          if (_unlocked && state.result != null)
            _PdfDownloadButton(
              resumeText: state.result!.improvedText,
              name: widget.userName,
            ),
        ],
        bottom: _unlocked && state.result != null
            ? TabBar(
                controller: _tab,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                tabs: [
                  const Tab(text: 'Improved Resume'),
                  Tab(
                    text: state.result != null
                        ? 'Changes (${state.result!.bulletChanges.length})'
                        : 'Changes',
                  ),
                ],
              )
            : null,
      ),
      body: _unlocked ? _unlockedBody(state) : _lockedBody(),
    );
  }

  Widget _lockedBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _HeaderCard(),
          const SizedBox(height: 20),
          _BlurredPreview(resumeText: _effectiveResumeText),
          const SizedBox(height: 24),
          _FeatureList(),
          const SizedBox(height: 28),
          _UnlockButton(plan: PaymentPlan.fixResume, onTap: _handleUnlock),
          const SizedBox(height: 10),
          const Text(
            'One-time payment · Instant access · No subscription',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _unlockedBody(FixResumeState state) {
    if (state.isLoading) {
      return const PremiumLoadingView(
        message: 'AI is analyzing and rewriting your resume…',
      );
    }
    if (state.error != null) {
      return PremiumErrorView(error: state.error!, onRetry: _startFix);
    }
    if (state.result == null) return const SizedBox.shrink();
    return TabBarView(
      controller: _tab,
      children: [
        _ImprovedResumeTab(result: state.result!),
        _ChangesTab(result: state.result!),
      ],
    );
  }
}

// ─── Locked Widgets ───────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D5BE3), Color(0xFF1A3DA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D5BE3).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_fix_high,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fix My Resume',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'AI rewrites bullets, summary & boosts your ATS score',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredPreview extends StatelessWidget {
  final String resumeText;
  const _BlurredPreview({required this.resumeText});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = resumeText.length > 500
        ? resumeText.substring(0, 500)
        : resumeText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.preview, size: 15, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            const Text(
              'Preview of Improved Version',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 11, color: AppTheme.warning),
                  SizedBox(width: 4),
                  Text(
                    'Locked',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A1D27)
                    : const Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Text(
                _fakeImproved(preview),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: 14,
                overflow: TextOverflow.fade,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 160,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                Colors.transparent,
                                const Color(0xFF0F1117).withOpacity(0.95),
                              ]
                            : [
                                Colors.transparent,
                                Colors.white.withOpacity(0.95),
                              ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_open_rounded,
                      color: AppTheme.primary,
                      size: 26,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Unlock to see your fully improved resume',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fakeImproved(String text) => text
      .replaceAll('worked on', 'Engineered')
      .replaceAll('made', 'Developed')
      .replaceAll('built', 'Architected')
      .replaceAll('helped', 'Collaborated to deliver')
      .replaceAll('responsible for', 'Led');
}

class _FeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final features = [
      (
        '📈 ATS Score Boost',
        'Before vs after score — watch your ATS rank jump',
      ),
      (
        '⚡ Bullet Rewrite',
        'Every weak line rewritten with action verbs + metrics',
      ),
      ('✍️ Summary Rewrite', 'Punchy 2-3 line summary that hooks recruiters'),
      (
        '📊 Metrics Added',
        'Quantified impact added (~estimates where unknown)',
      ),
      ('📄 PDF Download', 'Clean ATS-optimized PDF ready to apply'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What you get:',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 14),
        ...features.map(
          (f) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D27) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        f.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UnlockButton extends StatelessWidget {
  final PaymentPlan plan;
  final VoidCallback onTap;
  const _UnlockButton({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppTheme.primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_fix_high, size: 20),
            const SizedBox(width: 10),
            Text(
              'Fix My Resume · ${plan.displayPrice}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 1: Improved Resume ───────────────────────────────────────────────────

class _ImprovedResumeTab extends StatelessWidget {
  final ImprovedResume result;
  const _ImprovedResumeTab({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ATS Score card
          _AtsScoreCard(
            scoreBefore: result.atsScoreBefore,
            scoreAfter: result.atsScoreAfter,
            sectionsImproved: result.sectionsImproved,
          ),
          const SizedBox(height: 12),

          // Share card — show off the improvement
          ShareResultBanner(
            toolName: 'Fix My Resume',
            scoreBefore: result.atsScoreBefore,
            scoreAfter: result.atsScoreAfter,
            highlight: result.sectionsImproved.isNotEmpty
                ? '${result.sectionsImproved.length} sections improved with impact metrics'
                : 'Bullets rewritten with action verbs and metrics',
          ),
          const SizedBox(height: 16),

          // New summary
          if (result.improvedSummary.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: AppTheme.primary,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'New Professional Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    result.improvedSummary,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Full resume text
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D27) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Full Improved Resume',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: result.improvedText),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text(
                          'Copy',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SelectableText(
                    result.improvedText,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.8,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Impact chips
          if (result.impactAdded.isNotEmpty) ...[
            const Text(
              'Impact Added:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.impactAdded
                  .map(
                    (i) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.success.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            color: AppTheme.success,
                            size: 12,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            i,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          // ── What to Do Next — real actionable suggestions ──────────────────
          if (result.actionableSuggestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'What to Do Next:',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Real actions to make your resume stronger:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            ...result.actionableSuggestions.map((s) => _ActionCard(s: s)),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final dynamic s;
  const _ActionCard({required this.s});

  Color get _color {
    if (s.priority == 'high') return AppTheme.error;
    if (s.priority == 'medium') return AppTheme.warning;
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s.priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      color: _color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.suggestion,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ATS Score Card ───────────────────────────────────────────────────────────

class _AtsScoreCard extends StatefulWidget {
  final int scoreBefore;
  final int scoreAfter;
  final List<String> sectionsImproved;
  const _AtsScoreCard({
    required this.scoreBefore,
    required this.scoreAfter,
    required this.sectionsImproved,
  });

  @override
  State<_AtsScoreCard> createState() => _AtsScoreCardState();
}

class _AtsScoreCardState extends State<_AtsScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _color(int s) => s >= 80
      ? AppTheme.success
      : s >= 60
      ? AppTheme.warning
      : AppTheme.error;

  String _label(int s) {
    if (s >= 85) return 'Excellent';
    if (s >= 75) return 'Strong';
    if (s >= 60) return 'Average';
    if (s >= 45) return 'Weak';
    return 'Very Low';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gain = widget.scoreAfter - widget.scoreBefore;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: AppTheme.success.withOpacity(0.08), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppTheme.success, size: 18),
              const SizedBox(width: 8),
              const Text(
                'ATS Score Improvement',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+$gain pts',
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _bar(
            'Before',
            widget.scoreBefore,
            _color(widget.scoreBefore),
            _label(widget.scoreBefore),
            0.0,
          ),
          const SizedBox(height: 14),
          _bar(
            'After',
            widget.scoreAfter,
            _color(widget.scoreAfter),
            _label(widget.scoreAfter),
            0.2,
          ),
          if (widget.sectionsImproved.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Sections improved:',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.sectionsImproved
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(String label, int score, Color color, String lbl, double delay) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final p = (((_anim.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
        return Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: score / 100 * p,
                  minHeight: 12,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(score * p).round()}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    lbl,
                    style: TextStyle(
                      fontSize: 9,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Tab 2: Changes Made ─────────────────────────────────────────────────────

class _ChangesTab extends StatelessWidget {
  final ImprovedResume result;
  const _ChangesTab({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final changes = result.bulletChanges;
    if (changes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: AppTheme.success.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            const Text(
              'Resume was already structured well.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Check Improved Resume tab for full rewrite.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        // Stats row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? const Color(0xFF1A1D27) : const Color(0xFFF5F7FF),
          child: Row(
            children: [
              _Pill('${changes.length}', 'Lines Fixed', AppTheme.primary),
              const SizedBox(width: 8),
              _Pill(
                '${result.impactAdded.length}',
                'Metrics Added',
                AppTheme.success,
              ),
              const SizedBox(width: 8),
              _Pill(
                '+${result.atsImprovement}',
                'ATS Points',
                AppTheme.warning,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: changes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ChangeCard(
              index: i + 1,
              total: changes.length,
              before: changes[i]['original'] ?? '',
              after: changes[i]['improved'] ?? '',
              reason: changes[i]['reason'] ?? '',
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Pill(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChangeCard extends StatefulWidget {
  final int index, total;
  final String before, after, reason;
  const _ChangeCard({
    required this.index,
    required this.total,
    required this.before,
    required this.after,
    required this.reason,
  });

  @override
  State<_ChangeCard> createState() => _ChangeCardState();
}

class _ChangeCardState extends State<_ChangeCard> {
  bool _showReason = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.index}/${widget.total}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bullet Improved',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                if (widget.reason.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _showReason = !_showReason),
                    child: Row(
                      children: [
                        Icon(
                          _showReason
                              ? Icons.lightbulb
                              : Icons.lightbulb_outline,
                          size: 14,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _showReason ? 'Hide' : 'Why?',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Before
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.close, color: AppTheme.error, size: 13),
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
                const SizedBox(height: 5),
                Text(
                  widget.before,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: Icon(Icons.south, size: 14, color: AppTheme.textSecondary),
            ),
          ),
          // After
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.success.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check, color: AppTheme.success, size: 13),
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
                const SizedBox(height: 5),
                Text(
                  widget.after,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Why reason
          if (_showReason && widget.reason.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb,
                    color: AppTheme.warning,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.reason,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── PDF Button ───────────────────────────────────────────────────────────────

class _PdfDownloadButton extends ConsumerWidget {
  final String resumeText;
  final String name;
  const _PdfDownloadButton({required this.resumeText, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fixResumeProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: state.isGeneratingPdf
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download PDF',
              onPressed: () async {
                await ref
                    .read(fixResumeProvider.notifier)
                    .generatePdf(resumeText: resumeText, name: name);
                final path = ref.read(fixResumeProvider).pdfPath;
                if (path != null && context.mounted) {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(
                              Icons.open_in_new,
                              color: AppTheme.primary,
                            ),
                            title: const Text('Open PDF'),
                            subtitle: const Text('View improved resume'),
                            onTap: () {
                              Navigator.pop(context);
                              ResumePdfService().openPdf(path);
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.share,
                              color: AppTheme.accent,
                            ),
                            title: const Text('Share PDF'),
                            subtitle: const Text(
                              'Send via WhatsApp, Email, etc.',
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              ResumePdfService().sharePdf(path);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }
}
