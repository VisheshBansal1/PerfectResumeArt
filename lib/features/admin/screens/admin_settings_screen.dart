// Recruiter Settings Screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class AdminSettingsBody extends ConsumerWidget {
  const AdminSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    final analyses = ref.watch(recruiterAnalysesProvider);
    final jobs = ref.watch(recruiterJobsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecruiterProfile(user?.name ?? 'Recruiter', user?.email ?? ''),
          const SizedBox(height: 28),
          _buildSectionLabel('My Data'),
          const SizedBox(height: 12),
          analyses.when(
            data: (list) => _buildDataInfo(context, ref, list),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _buildSectionLabel('My Vacancies'),
          const SizedBox(height: 12),
          jobs.when(
            data: (list) => _buildVacancyInfo(context, ref, list),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _buildSectionLabel('Account'),
          const SizedBox(height: 12),
          _buildAccountActions(context, ref),
          const SizedBox(height: 24),
          _buildSectionLabel('About'),
          const SizedBox(height: 12),
          _buildAbout(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRecruiterProfile(String name, String email) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.primary, AppTheme.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppTheme.primary.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        // Avatar
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              name.trim().isNotEmpty
                  ? name
                        .trim()
                        .split(' ')
                        .map((w) => w.isNotEmpty ? w[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase()
                  : 'R',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Recruiter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSectionLabel(String label) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary,
      letterSpacing: 0.8,
    ),
  );

  Widget _buildDataInfo(
    BuildContext context,
    WidgetRef ref,
    List<AnalysisModel> analyses,
  ) {
    final pending = analyses.where((a) => a.adminDecision == null).length;
    final totalFull = analyses.where((a) => a.analysisType == 'full').length;
    final totalAts = analyses.where((a) => a.analysisType == 'ats_only').length;

    return Column(
      children: [
        _InfoTile(
          icon: Icons.description_outlined,
          color: AppTheme.primary,
          title: 'Total Applications',
          trailing: '${analyses.length}',
        ),
        _InfoTile(
          icon: Icons.pending_outlined,
          color: AppTheme.warning,
          title: 'Pending Reviews',
          trailing: '$pending',
          trailingColor: pending > 0 ? AppTheme.warning : null,
        ),
        _InfoTile(
          icon: Icons.work_outline,
          color: AppTheme.primary,
          title: 'Job Role Analyses',
          trailing: '$totalFull',
        ),
        _InfoTile(
          icon: Icons.fact_check_outlined,
          color: const Color(0xFF7C3AED),
          title: 'ATS Checks',
          trailing: '$totalAts',
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.download_outlined,
          color: AppTheme.accent,
          title: 'Export Summary',
          subtitle: 'Export your analysis data as CSV (coming soon)',
          onTap: () => _showComingSoon(context, 'Export CSV'),
        ),
      ],
    );
  }

  Widget _buildVacancyInfo(
    BuildContext context,
    WidgetRef ref,
    List<JobModel> jobs,
  ) {
    final activeJobs = jobs.where((j) => j.isActive).length;

    return Column(
      children: [
        _InfoTile(
          icon: Icons.work_outline,
          color: AppTheme.success,
          title: 'Active Vacancies',
          trailing: '$activeJobs / ${jobs.length}',
        ),
        _ActionTile(
          icon: Icons.add_circle_outline,
          color: AppTheme.primary,
          title: 'Create New Vacancy',
          subtitle: 'Post a new position for candidates',
          onTap: () => context.push(AppRoutes.jobCreation),
        ),
      ],
    );
  }

  Widget _buildAccountActions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.refresh_outlined,
          color: AppTheme.primary,
          title: 'Refresh Data',
          subtitle: 'Re-fetch all analyses, jobs, and candidates',
          onTap: () {
            ref.invalidate(recruiterAnalysesProvider);
            ref.invalidate(recruiterJobsProvider);
            ref.invalidate(recruiterAnalyticsProvider);
            ref.invalidate(allAnalysesProvider);
            ref.invalidate(jobsProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Data refreshed'),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        _ActionTile(
          icon: Icons.logout_outlined,
          color: AppTheme.error,
          title: 'Sign Out',
          subtitle: 'Log out of your recruiter account',
          titleColor: AppTheme.error,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                    ),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            }
          },
        ),
      ],
    );
  }

  Widget _buildAbout() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.borderLight),
    ),
    child: const Column(
      children: [
        _AboutRow('App', 'AI Resume Analyzer'),
        _AboutRow('Version', '1.0.0'),
        _AboutRow('AI Model', 'Gemini 1.5 Pro'),
        _AboutRow('Storage', 'Firebase Firestore'),
        _AboutRow('Auth', 'Firebase Authentication'),
      ],
    ),
  );

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Shared tile widgets ──────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, trailing;
  final Color? trailingColor;

  const _InfoTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.trailing,
    this.trailingColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppTheme.cardLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.borderLight),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
        ),
        Text(
          trailing,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: trailingColor ?? AppTheme.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      tileColor: AppTheme.cardLight,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: titleColor ?? AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: onTap,
    ),
  );
}

class _AboutRow extends StatelessWidget {
  final String label, value;
  const _AboutRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    ),
  );
}
