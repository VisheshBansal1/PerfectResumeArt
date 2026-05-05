import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../providers/premium_providers.dart';
import 'fix_resume_screen.dart';
import 'jd_optimize_screen.dart';
import 'why_rejected_screen.dart';
import 'premium_tools_screen.dart';
import 'bundle_upgrade_screen.dart';

class PremiumHubScreen extends ConsumerWidget {
  final String resumeText;

  const PremiumHubScreen({super.key, required this.resumeText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.asData?.value;
    final unlocks = ref.watch(unlockProvider);

    final userEmail = user?.email ?? '';
    final userName = user?.name ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Premium Features',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header tagline
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Row(
                children: [
                  const Text('🚀', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Go From Rejected to Selected',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'AI-powered tools to make your resume land more interviews',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Section 1: Most Popular ──────────────────────────────────────
            _SectionLabel('🔥 Most Popular'),
            const SizedBox(height: 10),

            // Bundle card (highlighted)
            _BundleCard(
              isUnlocked: unlocks.contains('bundle'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BundleUpgradeScreen(
                    resumeText: resumeText,
                    userEmail: userEmail,
                    userName: userName,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Fix Resume
            _FeatureCard(
              emoji: '🔧',
              title: 'Fix My Resume',
              subtitle: 'Bullet rewrite + summary + impact + PDF',
              price: '₹39',
              color: AppTheme.primary,
              isUnlocked: unlocks.contains('fix_resume'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FixResumeScreen(
                    resumeText: resumeText,
                    userName: userName,
                    userEmail: userEmail,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // JD Optimize
            _FeatureCard(
              emoji: '🎯',
              title: 'JD Auto Optimization',
              subtitle: 'Paste JD → resume auto-matches keywords',
              price: '₹49',
              color: const Color(0xFF7C3AED),
              isUnlocked: unlocks.contains('jd_optimize'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JdOptimizeScreen(
                    resumeText: resumeText,
                    userName: userName,
                    userEmail: userEmail,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Section 2: Free Tools ────────────────────────────────────────
            _SectionLabel('🆓 Free Tools'),
            const SizedBox(height: 10),

            // Why rejected
            _FeatureCard(
              emoji: '📊',
              title: 'Why You Get Rejected',
              subtitle: 'Brutal honest feedback on your resume gaps',
              price: 'FREE',
              color: AppTheme.error,
              isUnlocked: true,
              isFree: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WhyRejectedScreen(resumeText: resumeText),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Project improver
            _FeatureCard(
              emoji: '🧠',
              title: 'Project Improver',
              subtitle: '"Made Flutter app" → Impressive 10x description',
              price: 'FREE',
              color: AppTheme.accent,
              isUnlocked: true,
              isFree: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProjectImproverScreen(),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Selection booster
            _FeatureCard(
              emoji: '📈',
              title: 'Add These to Get Selected',
              subtitle: 'Actionable list: what to add to your resume NOW',
              price: 'FREE',
              color: AppTheme.warning,
              isUnlocked: true,
              isFree: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SelectionBoosterScreen(resumeText: resumeText),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Section 3: Expert ────────────────────────────────────────────
            _SectionLabel('👤 Expert Help'),
            const SizedBox(height: 10),

            _FeatureCard(
              emoji: '👨‍💻',
              title: 'Human Expert Review',
              subtitle: 'Real expert rewrites your resume in 24 hrs',
              price: '₹129',
              color: Colors.grey[800]!,
              isUnlocked: unlocks.contains('human_review'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HumanReviewScreen(
                    userEmail: userEmail,
                    userName: userName,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      letterSpacing: 0.5,
    ),
  );
}

class _BundleCard extends StatelessWidget {
  final bool isUnlocked;
  final VoidCallback onTap;
  const _BundleCard({required this.isUnlocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFE53935)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Full Upgrade Bundle',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      _BestValueBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fix + JD Optimize + PDF — everything in one',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        '₹89',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹128',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUnlocked ? Icons.check : Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestValueBadge extends StatelessWidget {
  const _BestValueBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.25),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'SAVE ₹39',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String price;
  final Color color;
  final bool isUnlocked;
  final bool isFree;
  final VoidCallback onTap;
  final Color? priceColor;

  const _FeatureCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.color,
    required this.isUnlocked,
    required this.onTap,
    this.isFree = false,
    this.priceColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnlocked && !isFree
                ? AppTheme.success.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isFree)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FREE',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else if (isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '✓ UNLOCKED',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  Text(
                    price,
                    style: TextStyle(
                      color: priceColor ?? Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, color: Colors.white30, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
