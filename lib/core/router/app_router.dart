import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';

import '../../features/admin/screens/admin_main_screen.dart';
import '../../features/admin/screens/candidate_detail_screen.dart';
import '../../features/admin/screens/job_creation_screen.dart';
import '../../features/admin/screens/vacany_applicants_screen.dart';

import '../../features/analysis/screens/analysis_result_screen.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';

import '../../features/job_roles/screens/job_selection_screen.dart';

import '../../features/resume/screens/ats_checker_screen.dart';
import '../../features/resume/screens/home_screen.dart';
import '../../features/resume/screens/profile_screen.dart';
import '../../features/resume/screens/upload_resume_screen.dart';

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

    initialLocation: AppRoutes.login,

    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),

    redirect: (context, state) {
      final authAsync = ref.read(authStateProvider);

      final userAsync = ref.read(currentUserProvider);

      /// Prevent redirect while loading
      if (authAsync.isLoading || userAsync.isLoading) {
        return null;
      }

      final isLoggedIn = authAsync.value != null;

      final userRole = userAsync.value?.role;

      final location = state.matchedLocation;

      final isAuthRoute =
          location == AppRoutes.login || location == AppRoutes.register;

      /// Not logged in
      if (!isLoggedIn && !isAuthRoute) {
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
      /// AUTH
      /// ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          return const LoginScreen();
        },
      ),

      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) {
          return const RegisterScreen();
        },
      ),

      /// ─────────────────────────────────────
      /// USER
      /// ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) {
          return const HomeScreen();
        },
      ),

      GoRoute(
        path: AppRoutes.uploadResume,
        builder: (context, state) {
          return const UploadResumeScreen();
        },
      ),

      GoRoute(
        path: AppRoutes.atsChecker,
        builder: (context, state) {
          return const AtsCheckerScreen();
        },
      ),

      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) {
          return const ProfileScreen();
        },
      ),

      GoRoute(
        path: AppRoutes.jobSelection,
        builder: (context, state) {
          return const JobSelectionScreen();
        },
      ),

      GoRoute(
        path: AppRoutes.analysisResult,
        builder: (context, state) {
          final analysisId = state.pathParameters['analysisId'] ?? '';

          return AnalysisResultScreen(analysisId: analysisId);
        },
      ),

      /// ─────────────────────────────────────
      /// ADMIN
      /// ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) {
          return const AdminMainScreen();
        },

        routes: [
          GoRoute(
            path: 'job-creation',
            builder: (context, state) {
              return const JobCreationScreen();
            },
          ),

          GoRoute(
            path: 'vacancy/:jobId',
            builder: (context, state) {
              final jobId = state.pathParameters['jobId'] ?? '';

              return VacancyApplicantsScreen(jobId: jobId);
            },
          ),

          GoRoute(
            path: 'candidates/:candidateId',
            builder: (context, state) {
              final candidateId = state.pathParameters['candidateId'] ?? '';

              return CandidateDetailScreen(candidateId: candidateId);
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

  static const String profile = '/profile';

  static const String jobSelection = '/job-selection';

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
