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

// ─── Main Screen ──────────────────────────────────────────────────────────────

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

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // Check if already unlocked
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
        .fix(resumeText: widget.resumeText, jobTitle: '');
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
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Improved Resume'),
                  Tab(text: 'Changes Made'),
                ],
              )
            : null,
      ),
      body: _unlocked ? _unlockedBody(state) : _lockedBody(state),
    );
  }

  Widget _lockedBody(FixResumeState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _HeaderCard(),
          const SizedBox(height: 20),
          // Blurred preview of what they'll get
          _BlurredPreview(resumeText: widget.resumeText),
          const SizedBox(height: 24),
          _FeatureList(),
          const SizedBox(height: 24),
          _UnlockButton(plan: PaymentPlan.fixResume, onTap: _handleUnlock),
        ],
      ),
    );
  }

  Widget _unlockedBody(FixResumeState state) {
    if (state.isLoading) {
      return const PremiumLoadingView(message: 'AI is rewriting your resume…');
    }
    if (state.error != null) {
      return PremiumErrorView(error: state.error!, onRetry: _startFix);
    }
    if (state.result == null) return const SizedBox.shrink();

    final result = state.result!;
    return TabBarView(
      controller: _tab,
      children: [
        // Tab 1: Improved resume full text
        _ImprovedTextTab(result: result),
        // Tab 2: Changes made (before/after)
        _ChangesTab(result: result),
      ],
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

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
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'AI rewrites every bullet, summary & adds impact metrics',
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
    final preview = resumeText.length > 400
        ? resumeText.substring(0, 400)
        : resumeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.preview, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              'Preview (Improved Version)',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '🔒 Locked',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            // Background text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                _fakeImproved(preview),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 12,
                overflow: TextOverflow.fade,
              ),
            ),
            // Blur overlay on bottom 60%
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 150,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Lock label in center
            const Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.lock, color: Color(0xFF2D5BE3), size: 24),
                    SizedBox(height: 4),
                    Text(
                      'Unlock to see full improved resume',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D5BE3),
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

  /// Shows a slightly "improved-looking" fake preview to entice user
  String _fakeImproved(String text) {
    return text
        .replaceAll('worked on', 'Engineered')
        .replaceAll('made', 'Developed')
        .replaceAll('built', 'Architected')
        .replaceAll('helped', 'Collaborated to deliver')
        .replaceAll('did', 'Executed');
  }
}

class _FeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      (
        '🔄',
        'Bullet Rewrite',
        'Every weak bullet rewritten with action verbs + metrics',
      ),
      (
        '✍️',
        'Summary Rewrite',
        '2-3 line punchy professional summary that hooks recruiters',
      ),
      (
        '📈',
        'Impact Added',
        'Quantified outcomes added to each project (~estimate)',
      ),
      ('📄', 'PDF Download', 'Clean ATS-friendly PDF ready to send'),
      ('👁️', 'Before vs After', 'See exactly what changed and why'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What you get:',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 12),
        ...features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(f.$1, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        f.$3,
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
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_fix_high, size: 20),
            const SizedBox(width: 8),
            Text(
              'Fix My Resume · ${plan.displayPrice}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImprovedTextTab extends StatelessWidget {
  final ImprovedResume result;
  const _ImprovedTextTab({required this.result});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // New summary highlight
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star_rounded, color: AppTheme.primary, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'New Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result.improvedSummary,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Full improved text
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Full Improved Resume',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: result.improvedText),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
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
                const Divider(height: 16),
                SelectableText(
                  result.improvedText,
                  style: const TextStyle(fontSize: 12, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Impact added chips
          if (result.impactAdded.isNotEmpty) ...[
            const Text(
              'Impact Added:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.impactAdded
                  .map(
                    (i) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.success.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '✓ $i',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ChangesTab extends StatelessWidget {
  final ImprovedResume result;
  const _ChangesTab({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.bulletChanges.isEmpty) {
      return const Center(child: Text('No bullet changes found'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: result.bulletChanges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final change = result.bulletChanges[i];
        return BeforeAfterCard(
          before: change['original'] ?? '',
          after: change['improved'] ?? '',
        );
      },
    );
  }
}

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
              icon: const Icon(Icons.download),
              tooltip: 'Download PDF',
              onPressed: () async {
                await ref
                    .read(fixResumeProvider.notifier)
                    .generatePdf(resumeText: resumeText, name: name);
                final path = ref.read(fixResumeProvider).pdfPath;
                if (path != null && context.mounted) {
                  _showPdfOptions(context, path);
                }
              },
            ),
    );
  }

  void _showPdfOptions(BuildContext context, String path) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: AppTheme.primary),
              title: const Text('Open PDF'),
              onTap: () {
                Navigator.pop(context);
                ResumePdfService().openPdf(path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: AppTheme.accent),
              title: const Text('Share PDF'),
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
}
