import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/referral_service.dart';

import '../../features/admin/screens/admin_main_screen.dart';
import '../../features/admin/screens/candidate_detail_screen.dart';
import '../../features/admin/screens/job_creation_screen.dart';
import '../../features/admin/screens/vacany_applicants_screen.dart';

import '../../features/analysis/screens/analysis_result_screen.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';

import '../../features/job_roles/screens/job_selection_screen.dart';

import '../../features/referral/screens/earn_refer_screen.dart';
import '../../features/referral/screens/referral_admin_screen.dart';

import '../../features/resume/screens/about_screen.dart'; // TODO: adjust path if AboutScreen isn't here
import '../../features/resume/screens/ats_checker_screen.dart';
import '../../features/resume/screens/contact_screen.dart';
import '../../features/resume/screens/interview_prep_screen.dart';
import '../../features/resume/screens/jd_keyword_match_screen.dart';
import '../../features/resume/screens/progress_screen.dart';
import '../../features/resume/screens/home_screen.dart';
import '../../features/resume/screens/profile_screen.dart';
import '../../features/resume/screens/upload_resume_screen.dart';

/// ─────────────────────────────────────────────────────────
/// PAGE TRANSITION
/// ─────────────────────────────────────────────────────────
/// One shared transition for every route in the app instead of the
/// platform default — a soft fade combined with a gentle rise. Applying
/// this in one place upgrades navigation across the whole app at once
/// rather than needing a change in every screen.
CustomTransitionPage<void> _premiumPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 14 * (1 - curved.value)),
            child: child,
          ),
        ),
      );
    },
  );
}

/// ─────────────────────────────────────────────────────────
/// GOROUTER REFRESH STREAM
/// ─────────────────────────────────────────────────────────

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();

    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// ─────────────────────────────────────────────────────────
/// APP ROUTER
/// ─────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    debugLogDiagnostics: true,

    initialLocation: AppRoutes.home,

    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),

    redirect: (context, state) {
      // Referral Program: second capture attempt on every redirect
      // evaluation (which runs very early, on first load and every
      // navigation), not just main()'s one-time check at cold boot. Reads
      // the real browser URL directly via Uri.base rather than state.uri —
      // purely belt-and-suspenders so this keeps working the same way
      // regardless of exactly when in the router lifecycle it runs.
      // Fire-and-forget: a local storage write, no network call, and never
      // affects the redirect decision below — existing routing behavior is
      // unchanged.
      unawaited(ReferralService().captureReferralFromUrl());

      final authAsync = ref.read(authStateProvider);

      final userAsync = ref.read(currentUserProvider);

      /// Prevent redirect while loading
      if (authAsync.isLoading || userAsync.isLoading) {
        return null;
      }

      final isLoggedIn = authAsync.value != null;

      final userRole = userAsync.value?.role;

      // Referral links (and any other bare-domain hit, e.g. someone typing
      // just "perfectresumeart.in") land on "/" — there's no GoRoute
      // registered for that path, so without this it falls straight into
      // errorBuilder's "no routes for location" screen. Checked first and
      // against state.uri.path specifically (never state.matchedLocation,
      // which for an unmatched location can come through as the raw
      // "/?ref=CODE" string, query included — that would silently make a
      // plain `== '/'` check never fire). The `?ref=` code itself doesn't
      // need to survive this redirect: captureReferralFromUrl() above
      // already read it straight from the real browser URL (Uri.base), not
      // from wherever we're about to send the user.
      if (state.uri.path == '/') {
        return isLoggedIn ? AppRoutes.home : AppRoutes.login;
      }

      final location = state.matchedLocation;

      final isAuthRoute =
          location == AppRoutes.login || location == AppRoutes.register;

      // Most of the app works without an account — resume analysis, ATS
      // checking, JD matching, interview prep, etc. are all open. Only
      // account-tied screens (premium purchases, referrals, saved history,
      // profile) actually need a signed-in user. Everywhere else, tapping
      // in from the nav drawer / home already shows a "sign in to
      // continue" sheet before navigating (see core/widgets/auth_gate.dart)
      // — this redirect is just the safety net for someone hitting a
      // gated URL directly (e.g. a bookmarked link).
      final requiresAccount =
          location == AppRoutes.progress ||
          location == AppRoutes.profile ||
          location == AppRoutes.earnRefer ||
          location.startsWith('/analysis/');

      /// Not logged in, trying to reach an account-only screen
      if (!isLoggedIn && requiresAccount) {
        return AppRoutes.login;
      }

      /// Already logged in
      if (isLoggedIn && isAuthRoute) {
        return userRole == AppConstants.roleAdmin
            ? AppRoutes.adminDashboard
            : AppRoutes.home;
      }

      /// Admin protection
      if (location.startsWith('/admin')) {
        if (userRole != AppConstants.roleAdmin) {
          return AppRoutes.home;
        }
      }

      return null;
    },

    routes: [
      /// ─────────────────────────────────────
      /// ROOT
      /// ─────────────────────────────────────
      /// Referral links point at the bare domain root ("/?ref=CODE"), and
      /// with no GoRoute ever registered for "/" itself, that request had
      /// nowhere to match — hence "no routes for location". A GoRoute's
      /// `path` only ever matches against the path component of the URL;
      /// the query string is never part of that comparison. So this
      /// matches "/", "/?ref=CODE", "/?anything=whatever" — all of it —
      /// unconditionally, which the top-level `redirect` above could not
      /// guarantee on its own. `?ref=` itself doesn't need to survive this
      /// redirect: captureReferralFromUrl() (main.dart at cold boot, and
      /// again in the top-level redirect above) already reads it straight
      /// from the real browser URL via Uri.base, not from wherever this
      /// sends the user.
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final isLoggedIn = ref.read(authStateProvider).value != null;
          return isLoggedIn ? AppRoutes.home : AppRoutes.login;
        },
      ),

      /// ─────────────────────────────────────
      /// AUTH
      /// ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            _premiumPage(const LoginScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            _premiumPage(const RegisterScreen(), state),
      ),

      /// ─────────────────────────────────────
      /// USER
      /// ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) =>
            _premiumPage(const HomeScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.uploadResume,
        pageBuilder: (context, state) =>
            _premiumPage(const UploadResumeScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.atsChecker,
        pageBuilder: (context, state) =>
            _premiumPage(const AtsCheckerScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.interviewPrep,
        pageBuilder: (context, state) =>
            _premiumPage(const InterviewPrepScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.jdKeywordMatch,
        pageBuilder: (context, state) =>
            _premiumPage(const JdKeywordMatchScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.progress,
        pageBuilder: (context, state) =>
            _premiumPage(const ProgressScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) =>
            _premiumPage(const ProfileScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.jobSelection,
        pageBuilder: (context, state) =>
            _premiumPage(const JobSelectionScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.earnRefer,
        pageBuilder: (context, state) =>
            _premiumPage(const EarnReferScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.referralAdmin,
        pageBuilder: (context, state) =>
            _premiumPage(const ReferralAdminScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.contactUs,
        pageBuilder: (context, state) =>
            _premiumPage(const ContactScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.about,
        pageBuilder: (context, state) =>
            _premiumPage(const AboutScreen(), state),
      ),

      GoRoute(
        path: AppRoutes.analysisResult,
        pageBuilder: (context, state) {
          final analysisId = state.pathParameters['analysisId'] ?? '';

          return _premiumPage(
            AnalysisResultScreen(analysisId: analysisId),
            state,
          );
        },
      ),

      /// ─────────────────────────────────────
      /// ADMIN
      /// ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.adminDashboard,
        pageBuilder: (context, state) =>
            _premiumPage(const AdminMainScreen(), state),

        routes: [
          GoRoute(
            path: 'job-creation',
            pageBuilder: (context, state) =>
                _premiumPage(const JobCreationScreen(), state),
          ),

          GoRoute(
            path: 'vacancy/:jobId',
            pageBuilder: (context, state) {
              final jobId = state.pathParameters['jobId'] ?? '';

              return _premiumPage(VacancyApplicantsScreen(jobId: jobId), state);
            },
          ),

          GoRoute(
            path: 'candidates/:candidateId',
            pageBuilder: (context, state) {
              final candidateId = state.pathParameters['candidateId'] ?? '';

              return _premiumPage(
                CandidateDetailScreen(candidateId: candidateId),
                state,
              );
            },
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(child: Text('Page not found: ${state.error}')),
      );
    },
  );

  ref.onDispose(router.dispose);

  return router;
});

/// ─────────────────────────────────────────────────────────
/// ROUTE CONSTANTS
/// ─────────────────────────────────────────────────────────

class AppRoutes {
  static const String login = '/login';

  static const String register = '/register';

  static const String home = '/home';

  static const String uploadResume = '/upload-resume';

  static const String atsChecker = '/ats-checker';

  static const String interviewPrep = '/interview-prep';

  static const String jdKeywordMatch = '/jd-keyword-match';

  static const String progress = '/progress';

  static const String profile = '/profile';

  static const String jobSelection = '/job-selection';

  static const String earnRefer = '/earn-refer';

  static const String referralAdmin = '/admin/referral';

  static const String contactUs = '/contact';

  static const String about = '/about';

  static const String analysisResult = '/analysis/:analysisId';

  static const String adminDashboard = '/admin';

  static const String jobCreation = '/admin/job-creation';

  static const String vacancyApplicants = '/admin/vacancy/:jobId';

  static const String candidateDetail = '/admin/candidates/:candidateId';

  static String analysisResultWithId(String id) {
    return '/analysis/$id';
  }

  static String vacancyApplicantsWithId(String id) {
    return '/admin/vacancy/$id';
  }

  static String candidateDetailWithId(String id) {
    return '/admin/candidates/$id';
  }
}