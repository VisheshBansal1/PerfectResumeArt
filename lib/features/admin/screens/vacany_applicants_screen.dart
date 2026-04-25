// Screen showing all resumes/applicants for a specific vacancy.
// Navigated to via GoRouter (/admin/vacancy/:jobId) — no imperative push.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class VacancyApplicantsScreen extends ConsumerWidget {
  final String jobId;
  const VacancyApplicantsScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobByIdProvider(jobId));
    final allAnalyses = ref.watch(allAnalysesProvider);

    return jobAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        appBar: _buildAppBar(context, null, []),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        appBar: _buildAppBar(context, null, []),
        body: Center(child: Text('Error loading job: $e')),
      ),
      data: (job) {
        if (job == null) {
          return Scaffold(
            backgroundColor: AppTheme.surfaceLight,
            appBar: _buildAppBar(context, null, []),
            body: const Center(child: Text('Job not found')),
          );
        }

        final applicants = allAnalyses.maybeWhen(
          data: (list) =>
              list.where((a) => a.jobId == job.id).toList()
                ..sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt)),
          orElse: () => <AnalysisModel>[],
        );
        final isLoading = allAnalyses.isLoading;

        return Scaffold(
          backgroundColor: AppTheme.surfaceLight,
          appBar: _buildAppBar(context, job, applicants),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : applicants.isEmpty
              ? _EmptyApplicants(jobTitle: job.title)
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(allAnalysesProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      _ApplicantStats(applicants: applicants),
                      const SizedBox(height: 20),
                      const Text(
                        'Submitted Resumes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...applicants.map((a) => _ApplicantCard(analysis: a)),
                    ],
                  ),
                ),
        );
      },
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    JobModel? job,
    List<AnalysisModel> applicants,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // Use context.pop() so GoRouter manages the back stack correctly.
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.pop(),
      ),
      title: job == null
          ? const Text(
              'Applicants',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${applicants.length} applicant${applicants.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppTheme.borderLight, height: 1),
      ),
      actions: [
        if (job != null && job.isActive)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ApplicantStats extends StatelessWidget {
  final List<AnalysisModel> applicants;
  const _ApplicantStats({required this.applicants});

  @override
  Widget build(BuildContext context) {
    final pending = applicants.where((a) => a.adminDecision == null).length;
    final shortlisted = applicants
        .where(
          (a) =>
              a.adminDecision == 'Pass' || a.adminDecision == 'High Potential',
        )
        .length;
    final rejected = applicants.where((a) => a.adminDecision == 'Fail').length;
    final avgScore = applicants.isEmpty
        ? 0
        : (applicants.map((a) => a.overallScore).reduce((a, b) => a + b) /
                  applicants.length)
              .round();

    return Row(
      children: [
        _StatBox(
          label: 'Avg Score',
          value: '$avgScore%',
          color: AppTheme.primary,
        ),
        const SizedBox(width: 10),
        _StatBox(
          label: 'Pending',
          value: '$pending',
          color: pending > 0 ? AppTheme.warning : Colors.grey,
        ),
        const SizedBox(width: 10),
        _StatBox(
          label: 'Shortlisted',
          value: '$shortlisted',
          color: AppTheme.success,
        ),
        const SizedBox(width: 10),
        _StatBox(label: 'Rejected', value: '$rejected', color: AppTheme.error),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    ),
  );
}

class _ApplicantCard extends StatelessWidget {
  final AnalysisModel analysis;
  const _ApplicantCard({required this.analysis});

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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _scoreColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${analysis.overallScore}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _scoreColor,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: 9,
                      color: _scoreColor.withOpacity(0.8),
                    ),
                  ),
                ],
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
                    Expanded(
                      child: Text(
                        'Applicant ${analysis.userId.length >= 8 ? analysis.userId.substring(0, 8) : analysis.userId}…',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _DecisionChip(
                      decision: analysis.adminDecision,
                      aiRec: analysis.finalRecommendation,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ScoreTag('ATS ${analysis.atsScore}%', Colors.purple),
                    const SizedBox(width: 6),
                    _ScoreTag(
                      'Match ${analysis.matchScore}%',
                      AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    _ScoreTag(
                      'Project ${analysis.projectScore}%',
                      AppTheme.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat(
                    'MMM d, yyyy · h:mm a',
                  ).format(analysis.analyzedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 20),
        ],
      ),
    ),
  );
}

class _ScoreTag extends StatelessWidget {
  final String label;
  final Color color;
  const _ScoreTag(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _DecisionChip extends StatelessWidget {
  final String? decision;
  final String aiRec;
  const _DecisionChip({this.decision, required this.aiRec});

  @override
  Widget build(BuildContext context) {
    if (decision == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
        ),
        child: const Text(
          'Review',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Color color;
    switch (decision) {
      case 'Pass':
        color = AppTheme.success;
        break;
      case 'Fail':
        color = AppTheme.error;
        break;
      case 'High Potential':
        color = AppTheme.primary;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
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
}

class _EmptyApplicants extends StatelessWidget {
  final String jobTitle;
  const _EmptyApplicants({required this.jobTitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 36,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No resumes yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'No candidates have submitted resumes for "$jobTitle" yet.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
