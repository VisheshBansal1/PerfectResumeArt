import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    final analyses = ref.watch(userAnalysesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAvatar(user?.name ?? ''),
            const SizedBox(height: 16),
            Text(
              user?.name ?? 'User',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Member since ${user != null ? DateFormat('MMM yyyy').format(user.createdAt) : '—'}',
                style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 28),
            analyses.when(
              data: (list) => _buildStats(list),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            analyses.when(
              data: (list) => _buildBestAnalysis(context, list),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 28),
            _buildActions(context, ref),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildStats(List<AnalysisModel> list) {
    final total = list.length;
    final fullAnalyses = list.where((a) => a.analysisType == 'full').length;
    final atsChecks = list.where((a) => a.analysisType == 'ats_only').length;
    final customChecks = list.where((a) => a.analysisType == 'custom_tech').length;
    final avgScore = total == 0
        ? 0
        : (list.map((a) => a.overallScore).reduce((a, b) => a + b) / total).round();
    final avgAts = total == 0
        ? 0
        : (list.map((a) => a.atsScore).reduce((a, b) => a + b) / total).round();
    final shortlisted = list
        .where((a) => a.adminDecision == 'Pass' || a.adminDecision == 'High Potential')
        .length;

    return Column(
      children: [
        Row(
          children: [
            _StatBox(label: 'Total Analyses', value: '$total', color: AppTheme.primary),
            const SizedBox(width: 12),
            _StatBox(label: 'Avg Score', value: '$avgScore%', color: AppTheme.accent),
            const SizedBox(width: 12),
            _StatBox(label: 'Avg ATS', value: '$avgAts%', color: Colors.purple),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatBox(label: 'Job Role', value: '$fullAnalyses', color: AppTheme.primary),
            const SizedBox(width: 12),
            _StatBox(label: 'ATS Checks', value: '$atsChecks', color: Colors.purple),
            const SizedBox(width: 12),
            _StatBox(label: 'Shortlisted', value: '$shortlisted', color: AppTheme.success),
          ],
        ),
      ],
    );
  }

  Widget _buildBestAnalysis(BuildContext context, List<AnalysisModel> list) {
    if (list.isEmpty) return const SizedBox.shrink();

    final best = list.reduce((a, b) => a.overallScore > b.overallScore ? a : b);
    final color = best.overallScore >= 80
        ? AppTheme.success
        : best.overallScore >= 60
            ? AppTheme.primary
            : AppTheme.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Best Performance',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.push(AppRoutes.analysisResultWithId(best.id)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${best.overallScore}',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        best.jobTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('MMM d, yyyy').format(best.analyzedAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) => Column(
        children: [
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.grey[50],
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.history, color: AppTheme.primary, size: 20),
            ),
            title: const Text('Analysis History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: const Text('View all past analyses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pop(),
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: Colors.grey[50],
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.logout_outlined, color: AppTheme.error, size: 20),
            ),
            title: Text('Sign Out',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.error)),
            trailing: Icon(Icons.chevron_right, color: AppTheme.error),
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      );
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
