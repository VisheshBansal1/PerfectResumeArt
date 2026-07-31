import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../premium/screens/fix_resume_screen.dart';
import '../../premium/screens/premium_tools_screen.dart' show HumanReviewScreen;

/// Shown after any resume check — free or AI — to offer the two natural
/// next steps: have AI rewrite it, or have a professional human review it.
/// Used identically everywhere a check result is shown, so the "what next"
/// moment never looks different depending on which tool the person used.
class NextStepsCta extends ConsumerWidget {
  final String resumeText;

  const NextStepsCta({super.key, required this.resumeText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.maybeWhen(data: (u) => u, orElse: () => null);
    final userName = user?.name ?? '';
    final userEmail = user?.email ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What next?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(
          'Two ways to fix what this check found',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 360;
            final cards = [
              _OptionCard(
                icon: Icons.auto_fix_high,
                title: 'Rewrite with AI',
                subtitle: 'Fixes bullets, keywords, and formatting in under a minute',
                price: '₹39',
                colors: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
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
              _OptionCard(
                icon: Icons.support_agent,
                title: 'Human Review',
                subtitle: 'A professional reviewer reads and annotates your resume',
                price: '₹129',
                colors: const [Color(0xFF0F766E), Color(0xFF115E59)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HumanReviewScreen(
                      userName: userName,
                      userEmail: userEmail,
                    ),
                  ),
                ),
              ),
            ];
            if (narrow) {
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 12),
                  cards[1],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;
  final List<Color> colors;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    price,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
