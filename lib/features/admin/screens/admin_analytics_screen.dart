// Recruiter Analytics — shows data only for the recruiter's own vacancies.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class AdminAnalyticsBody extends ConsumerWidget {
  const AdminAnalyticsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(recruiterAnalyticsProvider);
    final analysesAsync = ref.watch(recruiterAnalysesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recruiterAnalyticsProvider);
        ref.invalidate(recruiterAnalysesProvider);
        ref.invalidate(allAnalysesProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            analyticsAsync.when(
              data: (data) => _buildContent(context, data, analysesAsync),
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, dynamic> data,
    AsyncValue<List<AnalysisModel>> analysesAsync,
  ) {
    final total = data['total'] as int;
    final avgScore = data['avgScore'] as int;
    final scoreRanges = data['scoreRanges'] as Map<String, dynamic>;
    final decisions = data['decisions'] as Map<String, dynamic>;
    final byType = data['byType'] as Map<String, dynamic>;
    final jobStats = data['jobStats'] as Map<String, dynamic>;

    if (total == 0) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Overview'),
        const SizedBox(height: 12),
        _buildOverviewCards(total, avgScore, decisions),
        const SizedBox(height: 24),

        _sectionTitle('Recruiter Decisions'),
        const SizedBox(height: 12),
        _buildDecisionChart(decisions, total),
        const SizedBox(height: 24),

        _sectionTitle('Score Distribution'),
        const SizedBox(height: 12),
        _buildScoreDistribution(scoreRanges, total),
        const SizedBox(height: 24),

        _sectionTitle('Analysis Types Used'),
        const SizedBox(height: 12),
        _buildTypeBreakdown(byType, total),
        const SizedBox(height: 24),

        if (jobStats.isNotEmpty) ...[
          _sectionTitle('Per Vacancy Stats'),
          const SizedBox(height: 12),
          _buildJobStats(jobStats),
          const SizedBox(height: 24),
        ],

        analysesAsync.when(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Top Missing Skills'),
                    const SizedBox(height: 12),
                    _buildMissingSkillsInsight(list),
                    const SizedBox(height: 40),
                  ],
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderLight),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.bar_chart_outlined,
            size: 32,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No data yet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Analytics will appear once candidates start applying to your vacancies.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimary,
    ),
  );

  Widget _buildOverviewCards(
    int total,
    int avgScore,
    Map<String, dynamic> decisions,
  ) {
    final shortlisted =
        (decisions['pass'] as int) + (decisions['highPotential'] as int);
    final conversionRate = total == 0 ? 0.0 : (shortlisted / total * 100);

    return Row(
      children: [
        _BigStatCard(
          label: 'Total Analyzed',
          value: '$total',
          icon: Icons.description_outlined,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 12),
        _BigStatCard(
          label: 'Avg Score',
          value: '$avgScore%',
          icon: Icons.show_chart,
          color: AppTheme.accent,
        ),
        const SizedBox(width: 12),
        _BigStatCard(
          label: 'Pass Rate',
          value: '${conversionRate.toStringAsFixed(0)}%',
          icon: Icons.trending_up,
          color: AppTheme.success,
        ),
      ],
    );
  }

  Widget _buildDecisionChart(Map<String, dynamic> decisions, int total) {
    final items = [
      ('High Potential', decisions['highPotential'] as int, AppTheme.primary),
      ('Pass', decisions['pass'] as int, AppTheme.success),
      ('Fail', decisions['fail'] as int, AppTheme.error),
      ('Pending Review', decisions['pending'] as int, AppTheme.textSecondary),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: items.map((item) {
          final pct = total == 0 ? 0.0 : item.$2 / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.$3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.$1,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${item.$2}  (${(pct * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: item.$3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppTheme.borderLight,
                    valueColor: AlwaysStoppedAnimation<Color>(item.$3),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScoreDistribution(Map<String, dynamic> ranges, int total) {
    final items = [
      ('Excellent  80–100', ranges['80-100'] as int, AppTheme.success),
      ('Good  60–80', ranges['60-80'] as int, AppTheme.primary),
      ('Average  40–60', ranges['40-60'] as int, AppTheme.warning),
      ('Low  0–40', ranges['0-40'] as int, AppTheme.error),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: items.map((item) {
          final pct = total == 0 ? 0.0 : item.$2 / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppTheme.borderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(item.$3),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${item.$2}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: item.$3,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypeBreakdown(Map<String, dynamic> byType, int total) {
    final items = [
      (
        'Job Role Match',
        byType['full'] as int,
        AppTheme.primary,
        Icons.work_outline,
      ),
      (
        'ATS Check Only',
        byType['ats_only'] as int,
        const Color(0xFF7C3AED),
        Icons.fact_check_outlined,
      ),
      (
        'Custom Tech Stack',
        byType['custom_tech'] as int,
        AppTheme.accent,
        Icons.code_outlined,
      ),
    ];

    return Row(
      children: items.map((item) {
        final pct = total == 0 ? 0.0 : item.$2 / total;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: item.$3.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: item.$3.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.$4, color: item.$3, size: 20),
                const SizedBox(height: 8),
                Text(
                  '${item.$2}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: item.$3,
                  ),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: item.$3.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$1,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildJobStats(Map<String, dynamic> jobStats) {
    final entries = jobStats.entries.toList();
    return Column(
      children: entries.map((entry) {
        final stats = entry.value as Map<String, dynamic>;
        final count = stats['count'] as int;
        final avgScore = count == 0
            ? 0
            : ((stats['totalScore'] as int) / count).round();
        final pass = stats['pass'] as int;
        final hp = stats['highPotential'] as int;
        final fail = stats['fail'] as int;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count apps  ·  avg $avgScore%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniDecisionBadge('HP $hp', AppTheme.primary),
                  const SizedBox(width: 8),
                  _MiniDecisionBadge('Pass $pass', AppTheme.success),
                  const SizedBox(width: 8),
                  _MiniDecisionBadge('Fail $fail', AppTheme.error),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMissingSkillsInsight(List<AnalysisModel> analyses) {
    final Map<String, int> skillCount = {};
    for (final a in analyses) {
      for (final s in a.missingSkills) {
        skillCount[s] = (skillCount[s] ?? 0) + 1;
      }
    }
    if (skillCount.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: const Text(
          'No missing skills data yet.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }

    final sorted = skillCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(10).toList();
    final maxCount = top.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: top.map((entry) {
          final pct = entry.value / maxCount;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppTheme.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.error,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${entry.value}×',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────

class _BigStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _BigStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _MiniDecisionBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniDecisionBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );
}
