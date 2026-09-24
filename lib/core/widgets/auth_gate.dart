import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../constants/app_theme.dart';
import '../router/app_router.dart';

/// Call this before navigating to anything that needs an account (premium
/// tools, referrals, progress history, profile). Returns true immediately
/// if already signed in — proceed as normal. If not signed in, shows a
/// "sign in to continue" sheet and returns false, so the caller should not
/// navigate.
///
/// Usage:
///   onTap: () async {
///     if (await requireAuth(context, ref, feature: 'Premium Tools')) {
///       // navigate
///     }
///   }
Future<bool> requireAuth(
  BuildContext context,
  WidgetRef ref, {
  required String feature,
}) async {
  final isLoggedIn = ref.read(authStateProvider).value != null;
  if (isLoggedIn) return true;

  if (!context.mounted) return false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SignInRequiredSheet(feature: feature),
  );

  return false;
}

/// The "sign in to continue" sheet itself — public so other entry points
/// that need this exact same check (e.g. PaywallSheet.show in
/// payment_service.dart, which is the single choke point every purchase
/// flow in the app goes through) can reuse it instead of duplicating it.
class SignInRequiredSheet extends StatelessWidget {
  final String feature;
  const SignInRequiredSheet({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sign in to use $feature',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your resumes, scores, and referrals are saved to your\naccount — takes about 15 seconds to set up.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.login);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Log In',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.register);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMain(context),
                  side: BorderSide(color: AppTheme.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe later',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
