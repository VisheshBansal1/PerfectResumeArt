import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class JobSelectionScreen extends ConsumerWidget {
  const JobSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(activeJobsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Select Job Role')),
      body: jobs.when(
        data: (list) => _JobList(jobs: list, onSelect: null),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// Bottom Sheet version for use in upload flow
class JobSelectionBottomSheet extends ConsumerWidget {
  const JobSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(activeJobsProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Select Job Role',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          jobs.when(
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No active job roles. Ask an admin to create one.'),
                  )
                : Flexible(
                    child: _JobList(
                      jobs: list,
                      onSelect: (job) => Navigator.of(context).pop(job),
                    ),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Error loading jobs: $e'),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  final List<JobModel> jobs;
  final ValueChanged<JobModel>? onSelect;

  const _JobList({required this.jobs, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shrinkWrap: true,
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _JobCard(job: jobs[i], onSelect: onSelect),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobModel job;
  final ValueChanged<JobModel>? onSelect;

  const _JobCard({required this.job, required this.onSelect});

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onSelect != null ? () => onSelect!(job) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${job.minExperience}+ yrs',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  job.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: job.requiredSkills
                      .take(5)
                      .map((s) => _SkillTag(s))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SkillTag extends StatelessWidget {
  final String skill;
  const _SkillTag(this.skill);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(skill, style: const TextStyle(fontSize: 11)),
      );
}
