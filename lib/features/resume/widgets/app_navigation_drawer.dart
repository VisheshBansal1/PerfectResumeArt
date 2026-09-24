// ─────────────────────────────────────────────────────────────────────────────
// lib/features/resume/widgets/app_navigation_drawer.dart
// One menu that lists every feature in the app. Built as a standalone,
// reusable widget (not baked into home_screen.dart) so it can be dropped
// into any other screen's Scaffold(drawer: ...) later with no changes.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/referral_service.dart';
import '../../../core/widgets/auth_gate.dart';
import '../../auth/providers/auth_provider.dart';
import '../../premium/screens/premium_hub_screen.dart';

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  void _closeThen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop(); // close the drawer first
    action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);
    final isLoggedIn = ref.watch(authStateProvider).value != null;
    final unreadCount = ref
        .watch(unreadReferralNotificationsProvider)
        .maybeWhen(data: (c) => c, orElse: () => 0);

    final initials = (user?.name ?? '').trim().isEmpty
        ? '?'
        : user!.name
              .trim()
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0] : '')
              .take(2)
              .join()
              .toUpperCase();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isLoggedIn
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            )
                          : const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: isLoggedIn
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Welcome',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                user?.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'You\u2019re browsing as a guest',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _closeThen(
                                  context,
                                  () => context.push(AppRoutes.login),
                                ),
                                child: const Text(
                                  'Sign in to save your progress',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Main features ───────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    onTap: () =>
                        _closeThen(context, () => context.go(AppRoutes.home)),
                  ),
                  _DrawerItem(
                    icon: Icons.auto_awesome,
                    label: 'Analyze for Job',
                    onTap: () => _closeThen(
                      context,
                      () => context.push(AppRoutes.uploadResume),
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.fact_check_outlined,
                    label: 'ATS Checker',
                    onTap: () => _closeThen(
                      context,
                      () => context.push(AppRoutes.atsChecker),
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.manage_search,
                    label: 'JD Keyword Match',
                    onTap: () => _closeThen(
                      context,
                      () => context.push(AppRoutes.jdKeywordMatch),
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.code_outlined,
                    label: 'Custom Tech Stack Check',
                    onTap: () => _closeThen(
                      context,
                      () =>
                          context.push(AppRoutes.uploadResume, extra: 'custom'),
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.trending_up,
                    label: 'My Progress',
                    onTap: () => _closeThen(context, () async {
                      if (await requireAuth(
                        context,
                        ref,
                        feature: 'My Progress',
                      )) {
                        if (context.mounted) context.push(AppRoutes.progress);
                      }
                    }),
                  ),
                  _DrawerItem(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Premium Tools',
                    onTap: () => _closeThen(context, () async {
                      if (await requireAuth(
                        context,
                        ref,
                        feature: 'Premium Tools',
                      )) {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PremiumHubScreen(resumeText: ''),
                            ),
                          );
                        }
                      }
                    }),
                  ),
                  _DrawerItem(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Earn & Refer',
                    badgeCount: unreadCount,
                    onTap: () => _closeThen(context, () async {
                      if (await requireAuth(
                        context,
                        ref,
                        feature: 'Earn & Refer',
                      )) {
                        if (context.mounted) context.push(AppRoutes.earnRefer);
                      }
                    }),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(height: 1),
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    onTap: () => _closeThen(context, () async {
                      if (await requireAuth(
                        context,
                        ref,
                        feature: 'your Profile',
                      )) {
                        if (context.mounted) context.push(AppRoutes.profile);
                      }
                    }),
                  ),
                  _DrawerItem(
                    icon: Icons.support_agent_outlined,
                    label: 'Contact Us',
                    onTap: () => _closeThen(
                      context,
                      () => context.push(AppRoutes.contactUs),
                    ),
                  ),
                  if (user?.role == 'admin')
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Referral Program Admin',
                      onTap: () => _closeThen(
                        context,
                        () => context.push(AppRoutes.referralAdmin),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 1),
            isLoggedIn
                ? _DrawerItem(
                    icon: Icons.logout_outlined,
                    label: 'Sign Out',
                    iconColor: AppTheme.error,
                    labelColor: AppTheme.error,
                    onTap: () => _closeThen(context, () async {
                      await ref.read(authNotifierProvider.notifier).logout();
                      if (context.mounted) context.go(AppRoutes.home);
                    }),
                  )
                : _DrawerItem(
                    icon: Icons.login_rounded,
                    label: 'Sign In',
                    iconColor: AppTheme.primary,
                    labelColor: AppTheme.primary,
                    onTap: () => _closeThen(
                      context,
                      () => context.push(AppRoutes.login),
                    ),
                  ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final int badgeCount;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.textSecondary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: labelColor,
        ),
      ),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
