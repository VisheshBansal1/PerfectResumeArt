import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/resume_improve_service.dart';
import '../../../core/services/payment_service.dart';
import '../../../providers/premium_providers.dart';

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
    required this.resumeText,
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
      ref
          .read(selectionBoosterProvider.notifier)
          .analyze(resumeText: widget.resumeText, jobTitle: widget.jobTitle);
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

class HumanReviewScreen extends ConsumerWidget {
  final String userEmail;
  final String userName;

  const HumanReviewScreen({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocks = ref.watch(unlockProvider);
    final isUnlocked = unlocks.contains('human_review');

    Future<void> handleRequest() async {
      final paid = await PaywallSheet.show(
        context,
        plan: PaymentPlan.humanReview,
        userEmail: userEmail,
        userName: userName,
      );
      if (paid && context.mounted) {
        await ref.read(unlockProvider.notifier).unlock('human_review');
        // Show confirmation
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success),
                  SizedBox(width: 8),
                  Text('Request Submitted!'),
                ],
              ),
              content: Text(
                'Your payment is confirmed. Our expert will review your resume and send the improved version to $userEmail within 24 hours.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }

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
                    'Your resume gets manually reviewed and rewritten by an\nexperienced technical resume writer — in 24 hours.',
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
            const SizedBox(height: 24),

            // What you get
            const Text(
              'What you get:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 14),
            ...[
              (
                '👤',
                'Human Expert',
                'A real person with 5+ years of tech resume writing experience',
              ),
              (
                '⏱️',
                '24 Hour Delivery',
                'Improved resume sent to your email within 24 hours',
              ),
              (
                '✏️',
                'Full Rewrite',
                'Every section reviewed and improved for your target role',
              ),
              (
                '💬',
                'Personal Feedback',
                'Voice note or written feedback on your resume\'s gaps',
              ),
              (
                '🔄',
                'One Free Revision',
                'One free edit round if you\'re not satisfied',
              ),
              (
                '🎯',
                'LinkedIn Tip',
                'Bonus: LinkedIn headline and About section suggestion',
              ),
            ].map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
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

            if (isUnlocked) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.success),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Submitted!',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Our expert will send your improved resume within 24 hours.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              // Price
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Expert Human Review',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      PaymentPlan.humanReview.displayPrice,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: handleRequest,
                  icon: const Icon(Icons.person_search, size: 20),
                  label: Text(
                    'Request Expert Review · ${PaymentPlan.humanReview.displayPrice}',
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
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
