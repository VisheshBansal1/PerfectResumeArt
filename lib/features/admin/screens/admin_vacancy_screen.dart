// Admin Vacancies Screen — shows admin's job postings, tap to see applicants
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class AdminVacanciesScreen extends ConsumerWidget {
  const AdminVacanciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use recruiter-scoped providers — pre-filtered by createdBy == currentUser.uid
    final jobs = ref.watch(recruiterJobsProvider);
    final analyses = ref.watch(recruiterAnalysesProvider);

    return jobs.when(
      data: (myJobs) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(jobsProvider);
            ref.invalidate(allAnalysesProvider);
          },
          child: myJobs.isEmpty
              ? _EmptyVacancies(
                  onCreateTap: () => context.push(AppRoutes.jobCreation),
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _HeaderSummary(jobs: myJobs, analyses: analyses),
                    const SizedBox(height: 20),
                    ...myJobs.map(
                      (job) => _VacancyCard(job: job, analyses: analyses),
                    ),
                  ],
                ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final List<JobModel> jobs;
  final AsyncValue<List<AnalysisModel>> analyses;

  const _HeaderSummary({required this.jobs, required this.analyses});

  @override
  Widget build(BuildContext context) {
    final active = jobs.where((j) => j.isActive).length;
    final totalApps = analyses.maybeWhen(
      data: (list) =>
          list.where((a) => jobs.any((j) => j.id == a.jobId)).length,
      orElse: () => 0,
    );
    final pending = analyses.maybeWhen(
      data: (list) => list
          .where(
            (a) => jobs.any((j) => j.id == a.jobId) && a.adminDecision == null,
          )
          .length,
      orElse: () => 0,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withBlue(220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _SummaryItem(
            label: 'Vacancies',
            value: '${jobs.length}',
            icon: Icons.work_rounded,
          ),
          _Divider(),
          _SummaryItem(
            label: 'Active',
            value: '$active',
            icon: Icons.check_circle_rounded,
          ),
          _Divider(),
          _SummaryItem(
            label: 'Applicants',
            value: '$totalApps',
            icon: Icons.people_rounded,
          ),
          _Divider(),
          _SummaryItem(
            label: 'Pending',
            value: '$pending',
            icon: Icons.pending_rounded,
            highlight: pending > 0,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 40,
    color: Colors.white.withOpacity(0.25),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool highlight;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: highlight ? Colors.amber[300] : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
        ),
      ],
    ),
  );
}

class _VacancyCard extends ConsumerWidget {
  final JobModel job;
  final AsyncValue<List<AnalysisModel>> analyses;

  const _VacancyCard({required this.job, required this.analyses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appList = analyses.maybeWhen(
      data: (list) => list.where((a) => a.jobId == job.id).toList(),
      orElse: () => <AnalysisModel>[],
    );
    final pending = appList.where((a) => a.adminDecision == null).length;
    final passed = appList
        .where(
          (a) =>
              a.adminDecision == 'Pass' || a.adminDecision == 'High Potential',
        )
        .length;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.vacancyApplicantsWithId(job.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: job.isActive
                          ? AppTheme.primary.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.work_rounded,
                      color: job.isActive ? AppTheme.primary : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            _StatusBadge(isActive: job.isActive),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${job.minExperience}+ yrs exp · ${job.requiredSkills.length} skills required',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Skills preview
            if (job.requiredSkills.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...job.requiredSkills.take(4).map((s) => _SkillTag(s)),
                    if (job.requiredSkills.length > 4)
                      _SkillTag(
                        '+${job.requiredSkills.length - 4}',
                        isMore: true,
                      ),
                  ],
                ),
              ),

            // Stats row
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _StatPill(
                    icon: Icons.description_outlined,
                    label: '${appList.length} Resumes',
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  if (pending > 0)
                    _StatPill(
                      icon: Icons.pending_rounded,
                      label: '$pending Pending',
                      color: AppTheme.warning,
                    ),
                  if (pending > 0) const SizedBox(width: 10),
                  _StatPill(
                    icon: Icons.check_circle_rounded,
                    label: '$passed Shortlisted',
                    color: AppTheme.success,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey[400],
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

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (isActive ? AppTheme.success : Colors.grey).withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.success : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.success : Colors.grey,
          ),
        ),
      ],
    ),
  );
}

class _SkillTag extends StatelessWidget {
  final String label;
  final bool isMore;
  const _SkillTag(this.label, {this.isMore = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isMore
          ? Colors.grey.withOpacity(0.08)
          : AppTheme.primary.withOpacity(0.07),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: isMore ? Colors.grey[600] : AppTheme.primary,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _EmptyVacancies extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyVacancies({required this.onCreateTap});

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
              color: AppTheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.work_outline, size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'No vacancies yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first job vacancy to start receiving and reviewing resumes from candidates.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Vacancy'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    ),
  );
}
