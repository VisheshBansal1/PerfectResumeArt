import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../core/constants/app_constants.dart';
import '../../premium/screens/premium_hub_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _onBackPressed(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit App'),
        content: const Text('Do you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _onBackPressed(context);
      },
      child: Scaffold(
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(user?.name ?? 'there'),
              const SizedBox(height: 20),
              _buildQuickStats(analyses),
              const SizedBox(height: 24),
              const Text(
                'Quick Tools',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildQuickTools(context),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Analyses',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                            .take(10)
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
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(String name) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // FIX: maxLines + ellipsis prevents long names from causing pixel overflow
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

  Widget _buildQuickStats(AsyncValue<List<AnalysisModel>> analyses) {
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

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          // FIX: IntrinsicHeight ensures dividers align correctly with items
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _GradientStatItem(label: 'Analyses', value: '${list.length}'),
                _VerticalDivider(),
                _GradientStatItem(label: 'Avg Score', value: '$avgScore%'),
                _VerticalDivider(),
                // FIX: shortened label "Best Score" → "Best" to avoid clipping on small screens
                _GradientStatItem(label: 'Best', value: '$bestScore%'),
                _VerticalDivider(),
                _GradientStatItem(label: 'Avg ATS', value: '$atsAvg%'),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

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
      // Premium banner card
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
          child: Row(children: [
            const Text('🚀', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Premium Resume Tools',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Fix · JD Match · Why Rejected · PDF · Expert Review',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('from ₹39',
                  style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.white30),
          ]),
        ),
      ),
    ],
  );

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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Upload your resume to get AI-powered\nfeedback and match scores.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
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

// FIX: renamed to _VerticalDivider to avoid any conflict with Flutter's Divider widget
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
        // FIX: FittedBox auto-scales text down if it would overflow the column
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
          // FIX: maxLines prevents subtitle from causing pixel overflow in narrow cards
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
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  // FIX: Wrap prevents score pills from overflowing on narrow screens
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
            // FIX: constrain max width so long status labels don't cause overflow
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
      // FIX: prevent status text from overflowing its constrained container
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    ),
  );
}
