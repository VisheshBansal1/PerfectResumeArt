import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../core/router/app_router.dart';

class CandidateDetailScreen extends ConsumerStatefulWidget {
  final String candidateId;
  const CandidateDetailScreen({super.key, required this.candidateId});

  @override
  ConsumerState<CandidateDetailScreen> createState() =>
      _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends ConsumerState<CandidateDetailScreen> {
  final _notesCtrl = TextEditingController();
  String? _selectedDecision;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitDecision(AnalysisModel analysis) async {
    if (_selectedDecision == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a decision')));
      return;
    }

    await ref
        .read(adminDecisionProvider.notifier)
        .makeDecision(
          analysisId: analysis.id,
          decision: _selectedDecision!,
          notes: _notesCtrl.text.trim(),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Decision saved: $_selectedDecision'),
          backgroundColor: AppTheme.success,
        ),
      );
      ref.invalidate(analysisProvider(widget.candidateId));
      ref.invalidate(allAnalysesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = ref.watch(analysisProvider(widget.candidateId));
    final decisionState = ref.watch(adminDecisionProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Candidate Detail'),
        backgroundColor: AppTheme.cardLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.borderLight, height: 1),
        ),
        actions: [
          analysis.whenOrNull(
                data: (a) => a != null
                    ? _TypeBadge(a.analysisType)
                    : const SizedBox.shrink(),
              ) ??
              const SizedBox.shrink(),
          const SizedBox(width: 8),
        ],
      ),
      body: analysis.when(
        data: (a) => a == null
            ? const Center(child: Text('Candidate not found'))
            : _buildBody(a, decisionState),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(AnalysisModel analysis, AsyncValue decisionState) {
    if (_selectedDecision == null && analysis.adminDecision != null) {
      _selectedDecision = analysis.adminDecision;
      _notesCtrl.text = analysis.adminNotes ?? '';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(analysis),
          const SizedBox(height: 20),
          _buildScoreSection(analysis),
          const SizedBox(height: 24),
          _buildAiRec(analysis),
          const SizedBox(height: 24),
          if (analysis.missingSkills.isNotEmpty) ...[
            _buildMissingSkills(analysis),
            const SizedBox(height: 24),
          ],
          if (analysis.projects.isNotEmpty) ...[
            _buildProjects(analysis),
            const SizedBox(height: 24),
          ],
          _buildStrengthsWeaknesses(analysis),
          const SizedBox(height: 24),
          // _buildSuggestions(analysis),
          // const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          _buildDecisionPanel(analysis, decisionState),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(AnalysisModel analysis) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              'ID: ${analysis.userId.substring(0, 12)}...',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const Spacer(),
            Text(
              DateFormat('MMM d, yyyy').format(analysis.analyzedAt),
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          analysis.jobTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (analysis.adminDecision != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.gavel, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Admin decision: ',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              _DecisionPill(analysis.adminDecision!),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _buildScoreSection(AnalysisModel analysis) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Scores',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      _ScoreBar(
        label: 'Overall',
        score: analysis.overallScore,
        color: _scoreColor(analysis.overallScore),
      ),
      const SizedBox(height: 8),
      _ScoreBar(
        label: 'Match',
        score: analysis.matchScore,
        color: AppTheme.primary,
      ),
      const SizedBox(height: 8),
      _ScoreBar(label: 'ATS', score: analysis.atsScore, color: Colors.purple),
      const SizedBox(height: 8),
      _ScoreBar(
        label: 'Projects',
        score: analysis.projectScore,
        color: AppTheme.accent,
      ),
    ],
  );

  Widget _buildAiRec(AnalysisModel analysis) {
    final isPos = analysis.finalRecommendation != 'Fail';
    final color = analysis.finalRecommendation == 'High Potential'
        ? AppTheme.primary
        : isPos
        ? AppTheme.success
        : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            analysis.finalRecommendation == 'High Potential'
                ? Icons.star_rounded
                : isPos
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Recommendation',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Text(
                  analysis.finalRecommendation,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'AI advisory only',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingSkills(AnalysisModel analysis) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Missing Skills',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
      ),
      const SizedBox(height: 8),
      Text(
        '${analysis.missingSkills.length} skill${analysis.missingSkills.length == 1 ? '' : 's'} not found in resume',
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.error,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: analysis.missingSkills
            .map(
              (s) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );

  Widget _buildProjects(AnalysisModel analysis) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Project Evaluation',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
      ),
      const SizedBox(height: 10),
      ...analysis.projects.map((p) => _ProjectTile(project: p)),
    ],
  );

  Widget _buildStrengthsWeaknesses(AnalysisModel analysis) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _ListSection(
          title: 'Strengths',
          items: analysis.strengths,
          color: AppTheme.success,
          icon: Icons.thumb_up_outlined,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _ListSection(
          title: 'Weaknesses',
          items: analysis.weaknesses,
          color: AppTheme.error,
          icon: Icons.thumb_down_outlined,
        ),
      ),
    ],
  );

  // Widget _buildSuggestions(AnalysisModel analysis) {
  //   if (analysis.suggestions.isEmpty) return const SizedBox.shrink();
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text(
  //         'AI Suggestions',
  //         style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
  //       ),
  //       const SizedBox(height: 10),
  //       ...analysis.suggestions.asMap().entries.map(
  //         (e) => Container(
  //           margin: const EdgeInsets.only(bottom: 8),
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: Colors.amber.withOpacity(0.06),
  //             borderRadius: BorderRadius.circular(8),
  //             border: Border.all(color: Colors.amber.withOpacity(0.2)),
  //           ),
  //           child: Row(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 '${e.key + 1}.',
  //                 style: TextStyle(
  //                   fontWeight: FontWeight.w600,
  //                   color: Colors.amber[700],
  //                   fontSize: 13,
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               Expanded(
  //                 child: Text(e.value, style: const TextStyle(fontSize: 13, color: Colors.black)),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildDecisionPanel(
    AnalysisModel analysis,
    AsyncValue decisionState,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.gavel, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Your Decision',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black38),
          ),
          const Spacer(),
          if (analysis.adminDecision != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Update',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'AI is advisory only — you have final authority.',
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          _DecisionButton(
            label: 'Pass',
            icon: Icons.check_circle_outline,
            color: AppTheme.success,
            selected: _selectedDecision == AppConstants.decisionPass,
            onTap: () =>
                setState(() => _selectedDecision = AppConstants.decisionPass),
          ),
          const SizedBox(width: 8),
          _DecisionButton(
            label: 'Fail',
            icon: Icons.cancel_outlined,
            color: AppTheme.error,
            selected: _selectedDecision == AppConstants.decisionFail,
            onTap: () =>
                setState(() => _selectedDecision = AppConstants.decisionFail),
          ),
          const SizedBox(width: 8),
          _DecisionButton(
            label: 'Top Pick',
            icon: Icons.star_outline,
            color: AppTheme.primary,
            selected: _selectedDecision == AppConstants.decisionHighPotential,
            onTap: () => setState(
              () => _selectedDecision = AppConstants.decisionHighPotential,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _notesCtrl,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Notes about this candidate (optional)...',
          filled: true,
          fillColor: AppTheme.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.borderLight),
          ),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: decisionState is AsyncLoading
              ? null
              : () => _submitDecision(analysis),
          child: decisionState is AsyncLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  analysis.adminDecision != null
                      ? 'Update Decision'
                      : 'Save Decision',
                ),
        ),
      ),
    ],
  );

  Color _scoreColor(int score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return AppTheme.primary;
    if (score >= 40) return AppTheme.warning;
    return AppTheme.error;
  }
}

// ─── Widget Components ─────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    final label = type == 'ats_only'
        ? 'ATS'
        : type == 'custom_tech'
        ? 'Custom'
        : 'Job Match';
    final color = type == 'ats_only'
        ? Colors.purple
        : type == 'custom_tech'
        ? AppTheme.accent
        : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final Color color;

  const _ScoreBar({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 64,
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: AppTheme.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 36,
        child: Text(
          '$score%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );
}

class _ProjectTile extends StatelessWidget {
  final ProjectAnalysis project;
  const _ProjectTile({required this.project});

  @override
  Widget build(BuildContext context) {
    final color = project.score >= 70
        ? AppTheme.success
        : project.score >= 50
        ? AppTheme.warning
        : AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${project.score}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${project.complexity} · ${project.techStack}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (project.issues.isNotEmpty)
                  Text(
                    '${project.issues.length} issue(s)',
                    style: TextStyle(fontSize: 11, color: AppTheme.warning),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  final IconData icon;

  const _ListSection({
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items
            .take(4)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 11, color: Colors.black)),
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(selected ? 1 : 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _DecisionPill extends StatelessWidget {
  final String decision;
  const _DecisionPill(this.decision);

  Color get color {
    switch (decision) {
      case 'Pass':
        return AppTheme.success;
      case 'Fail':
        return AppTheme.error;
      case 'High Potential':
        return AppTheme.primary;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      decision,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    ),
  );
}
