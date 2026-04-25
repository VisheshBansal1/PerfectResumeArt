// Recruiter Candidates Screen — applicants across the recruiter's own vacancies
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class AdminCandidatesScreen extends ConsumerStatefulWidget {
  const AdminCandidatesScreen({super.key});

  @override
  ConsumerState<AdminCandidatesScreen> createState() =>
      _AdminCandidatesScreenState();
}

class _AdminCandidatesScreenState extends ConsumerState<AdminCandidatesScreen> {
  String _filterDecision = 'All';
  String _filterJob = 'All';
  String _sortBy = 'Date';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AnalysisModel> _applyFilters(List<AnalysisModel> all) {
    var filtered = all.where((a) {
      final decisionMatch =
          _filterDecision == 'All' ||
          (_filterDecision == 'Pending'
              ? a.adminDecision == null
              : a.adminDecision == _filterDecision);
      final jobMatch = _filterJob == 'All' || a.jobTitle == _filterJob;
      final searchMatch =
          _searchQuery.isEmpty ||
          a.jobTitle.toLowerCase().contains(_searchQuery.toLowerCase());
      return decisionMatch && jobMatch && searchMatch;
    }).toList();

    switch (_sortBy) {
      case 'Score':
        filtered.sort((a, b) => b.overallScore.compareTo(a.overallScore));
        break;
      case 'ATS':
        filtered.sort((a, b) => b.atsScore.compareTo(a.atsScore));
        break;
      default:
        filtered.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // Only analyses from the recruiter's own jobs
    final analysesAsync = ref.watch(recruiterAnalysesProvider);

    return analysesAsync.when(
      data: (list) {
        final filtered = _applyFilters(list);
        final jobTitles = {'All', ...list.map((a) => a.jobTitle)}.toList();

        return Column(
          children: [
            _buildSearchBar(),
            _buildFilterRow(jobTitles),
            _buildCountBar(filtered.length, list.length),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(recruiterAnalysesProvider);
                        ref.invalidate(allAnalysesProvider);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _CandidateCard(
                          analysis: filtered[i],
                          rank: _sortBy == 'Score' ? i + 1 : null,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search by job title…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: AppTheme.cardLight,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    ),
  );

  Widget _buildFilterRow(List<String> jobTitles) {
    const decisions = ['All', 'Pending', 'Pass', 'Fail', 'High Potential'];
    const sortOptions = ['Date', 'Score', 'ATS'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _FilterChip(
            label: 'Job: $_filterJob',
            onTap: () => _showPicker(
              context,
              'Job Role',
              jobTitles,
              (v) => setState(() => _filterJob = v),
            ),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Status: $_filterDecision',
            onTap: () => _showPicker(
              context,
              'Status',
              decisions,
              (v) => setState(() => _filterDecision = v),
            ),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Sort: $_sortBy',
            onTap: () => _showPicker(
              context,
              'Sort By',
              sortOptions,
              (v) => setState(() => _sortBy = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBar(int filtered, int total) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: Row(
      children: [
        Text(
          '$filtered candidate${filtered == 1 ? '' : 's'}',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (filtered != total)
          Text(
            ' (filtered from $total)',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off_rounded, size: 48, color: AppTheme.borderLight),
        const SizedBox(height: 12),
        const Text(
          'No candidates match',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _filterDecision = 'All';
            _filterJob = 'All';
            _sortBy = 'Date';
            _searchQuery = '';
            _searchCtrl.clear();
          }),
          child: const Text('Clear Filters'),
        ),
      ],
    ),
  );

  void _showPicker(
    BuildContext context,
    String title,
    List<String> options,
    void Function(String) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Divider(),
            ...options.map(
              (o) => ListTile(
                dense: true,
                title: Text(o),
                onTap: () {
                  onSelect(o);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Candidate Card ───────────────────────────────────────────

class _CandidateCard extends StatelessWidget {
  final AnalysisModel analysis;
  final int? rank;
  const _CandidateCard({required this.analysis, this.rank});

  Color get _scoreColor {
    if (analysis.overallScore >= 80) return AppTheme.success;
    if (analysis.overallScore >= 60) return AppTheme.primary;
    if (analysis.overallScore >= 40) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push(AppRoutes.candidateDetailWithId(analysis.id)),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (rank != null) ...[
            SizedBox(
              width: 24,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: rank! <= 3
                      ? [
                          Colors.amber,
                          Colors.grey,
                          const Color(0xFFCD7F32),
                        ][rank! - 1]
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Score circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _scoreColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${analysis.overallScore}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _scoreColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.jobTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _ScorePill(
                      'ATS ${analysis.atsScore}%',
                      const Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 5),
                    _ScorePill(
                      'Match ${analysis.matchScore}%',
                      AppTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, h:mm a').format(analysis.analyzedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusChip(analysis.adminDecision, analysis.finalRecommendation),
              const SizedBox(height: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppTheme.borderLight,
              ),
            ],
          ),
        ],
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
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String? decision;
  final String aiRec;
  const _StatusChip(this.decision, this.aiRec);

  @override
  Widget build(BuildContext context) {
    if (decision == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
        ),
        child: const Text(
          'Pending',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final color = _decisionColor(decision!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        decision!,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _decisionColor(String d) {
    switch (d) {
      case 'Pass':
        return AppTheme.success;
      case 'Fail':
        return AppTheme.error;
      case 'High Potential':
        return AppTheme.primary;
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: const BorderSide(color: AppTheme.borderLight).asBorderSide,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 3),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    ),
  );
}

extension on BorderSide {
  Border get asBorderSide => Border.all(color: color, width: width);
}
