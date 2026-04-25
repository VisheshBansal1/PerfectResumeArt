import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/providers.dart';
import '../../auth/providers/auth_provider.dart';
import 'admin_candidates_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_vacancy_screen.dart';

class AdminMainScreen extends ConsumerStatefulWidget {
  const AdminMainScreen({super.key});

  @override
  ConsumerState<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends ConsumerState<AdminMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AdminVacanciesScreen(),
    AdminCandidatesScreen(),
    AdminAnalyticsBody(),
    AdminSettingsBody(),
  ];

  final List<String> _titles = const [
    'My Vacancies',
    'Applicants',
    'Analytics',
    'Settings',
  ];

  final List<IconData> _icons = const [
    Icons.work_outline,
    Icons.people_outline,
    Icons.bar_chart_outlined,
    Icons.settings_outlined,
  ];

  final List<IconData> _selectedIcons = const [
    Icons.work_rounded,
    Icons.people_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_rounded,
  ];

  Future<void> _onBackPressed() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit App'),
        content: const Text('Do you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) SystemNavigator.pop();
  }

  void _refreshCurrentTab() {
    ref.invalidate(recruiterAnalysesProvider);
    ref.invalidate(recruiterJobsProvider);
    ref.invalidate(recruiterAnalyticsProvider);
    ref.invalidate(jobsProvider);
    ref.invalidate(allAnalysesProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Badge count from recruiter's analyses only
    final pendingCount = ref
        .watch(recruiterAnalysesProvider)
        .maybeWhen(
          data: (list) => list.where((a) => a.adminDecision == null).length,
          orElse: () => 0,
        );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceLight,
        appBar: AppBar(
          title: Text(
            _titles[_currentIndex],
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          automaticallyImplyLeading: false,
          backgroundColor: AppTheme.cardLight,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppTheme.borderLight, height: 1),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              onPressed: _refreshCurrentTab,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, size: 22),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (context.mounted) context.go(AppRoutes.login);
                }
              },
              tooltip: 'Sign Out',
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardLight,
            border: Border(top: BorderSide(color: AppTheme.borderLight)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 64,
              child: Row(
                children: List.generate(4, (i) {
                  final isSelected = _currentIndex == i;
                  // Badge on Applicants tab (index 1)
                  final showBadge = i == 1 && pendingCount > 0;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentIndex = i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  isSelected ? _selectedIcons[i] : _icons[i],
                                  size: 22,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              if (showBadge)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        pendingCount > 9
                                            ? '9+'
                                            : '$pendingCount',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _titles[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
