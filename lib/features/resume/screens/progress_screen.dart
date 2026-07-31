import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../widgets/local_scan_widgets.dart' show scanScoreColor;

/// Turns the analyses the user has already run into a trend they can see —
/// a reason to come back to this app and re-check instead of running a
/// one-off score on some other site with no memory of last time.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysesAsync = ref.watch(userAnalysesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Progress')),
      body: analysesAsync.when(
        data: (list) => _buildBody(context, list),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load your history. Pull to refresh or try again shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<AnalysisModel> raw) {
    if (raw.isEmpty) return _buildEmptyState(context);

    final chronological = [...raw]..sort((a, b) => a.analyzedAt.compareTo(b.analyzedAt));
    final best = chronological.reduce((a, b) => a.overallScore >= b.overallScore ? a : b);
    final latest = chronological.last;
    final first = chronological.first;
    final avg = (chronological.map((a) => a.overallScore).reduce((a, b) => a + b) / chronological.length).round();
    final delta = latest.overallScore - first.overallScore;

    final byType = <String, int>{};
    for (final a in chronological) {
      byType[a.analysisType] = (byType[a.analysisType] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(chronological.length),
          const SizedBox(height: 20),
          _buildStatRow(best: best.overallScore, avg: avg, latest: latest.overallScore, delta: delta),
          const SizedBox(height: 24),
          const Text('Score over time', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            chronological.length > 10
                ? 'Last 10 checks shown, most recent on the right'
                : 'Most recent on the right',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          _ScoreTrendChart(analyses: chronological),
          const SizedBox(height: 28),
          if (byType.length > 1) ...[
            const Text('By check type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _buildTypeBreakdown(byType),
            const SizedBox(height: 28),
          ],
          const Text('History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...chronological.reversed.map((a) => _HistoryTile(analysis: a)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(int count) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.accent, const Color(0xFF00997A)],
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
          child: const Icon(Icons.trending_up, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Progress',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '$count check${count == 1 ? '' : 's'} run so far',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildStatRow({required int best, required int avg, required int latest, required int delta}) {
    Widget stat(String label, String value, {Color? color}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color ?? AppTheme.textPrimary),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );

    final deltaLabel = delta > 0 ? '+$delta' : '$delta';
    final deltaColor = delta > 0 ? AppTheme.success : (delta < 0 ? AppTheme.error : AppTheme.textSecondary);

    return Row(
      children: [
        stat('BEST', '$best', color: scanScoreColor(best)),
        const SizedBox(width: 10),
        stat('AVERAGE', '$avg', color: scanScoreColor(avg)),
        const SizedBox(width: 10),
        stat('LATEST', '$latest', color: scanScoreColor(latest)),
        const SizedBox(width: 10),
        stat('CHANGE', deltaLabel, color: deltaColor),
      ],
    );
  }

  Widget _buildTypeBreakdown(Map<String, int> byType) {
    String label(String t) => switch (t) {
      'ats_only' => 'ATS Checks',
      'full' => 'Job-Matched',
      'custom_tech' => 'Custom Tech',
      _ => t,
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: byType.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${label(e.key)} · ${e.value}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 56, color: AppTheme.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            'No checks yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Run your first ATS check and your score history will start showing up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.atsChecker),
            child: const Text('Run ATS Check'),
          ),
        ],
      ),
    ),
  );
}

class _ScoreTrendChart extends StatelessWidget {
  final List<AnalysisModel> analyses; // chronological, oldest first

  const _ScoreTrendChart({required this.analyses});

  @override
  Widget build(BuildContext context) {
    const maxBars = 10;
    final shown = analyses.length > maxBars ? analyses.sublist(analyses.length - maxBars) : analyses;
    const chartHeight = 120.0;

    return SizedBox(
      height: chartHeight + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: shown.map((a) {
          final fraction = (a.overallScore / 100).clamp(0.04, 1.0);
          final color = scanScoreColor(a.overallScore);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${a.overallScore}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: chartHeight * fraction,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('d/M').format(a.analyzedAt),
                    style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final AnalysisModel analysis;
  const _HistoryTile({required this.analysis});

  String get _typeLabel => switch (analysis.analysisType) {
    'ats_only' => 'ATS Check',
    'full' => 'Job Match',
    'custom_tech' => 'Custom Tech Match',
    _ => analysis.analysisType,
  };

  @override
  Widget build(BuildContext context) {
    final color = scanScoreColor(analysis.overallScore);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(AppRoutes.analysisResultWithId(analysis.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Text(
                '${analysis.overallScore}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.jobTitle.isEmpty ? _typeLabel : analysis.jobTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_typeLabel · ${DateFormat('MMM d, yyyy').format(analysis.analyzedAt)}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
