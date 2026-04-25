import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/resume/screens/upload_resume_screen.dart';
import '../../features/resume/screens/home_screen.dart';
import '../../features/resume/screens/ats_checker_screen.dart';
import '../../features/resume/screens/profile_screen.dart';
import '../../features/job_roles/screens/job_selection_screen.dart';
import '../../features/analysis/screens/analysis_result_screen.dart';
import '../../features/admin/screens/admin_main_screen.dart';
import '../../features/admin/screens/job_creation_screen.dart';
import '../../features/admin/screens/candidate_detail_screen.dart';
import '../../features/admin/screens/vacany_applicants_screen.dart';
import '../../core/constants/app_constants.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final isLoggedIn = authState.when(
        data: (user) => user != null,
        loading: () => false,
        error: (_, __) => false,
      );

      final userRole = currentUser.when(
        data: (user) => user?.role,
        loading: () => null,
        error: (_, __) => null,
      );

      final isLoggingIn =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.roleSelection;

      if (!isLoggedIn && !isLoggingIn) return AppRoutes.login;

      if (isLoggedIn && isLoggingIn) {
        if (userRole == AppConstants.roleAdmin) return AppRoutes.adminDashboard;
        return AppRoutes.home;
      }

      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      if (isAdminRoute &&
          userRole != null &&
          userRole != AppConstants.roleAdmin) {
        return AppRoutes.home;
      }

      final isUserRoute =
          state.matchedLocation == AppRoutes.home ||
          state.matchedLocation == AppRoutes.uploadResume ||
          state.matchedLocation == AppRoutes.atsChecker;
      if (isUserRoute && userRole == AppConstants.roleAdmin) {
        return AppRoutes.adminDashboard;
      }

      return null;
    },
    routes: [
      // ─── Auth Routes ─────────────────────────────────────────
      GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (c, s) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.roleSelection,
        builder: (c, s) => const RoleSelectionScreen(),
      ),

      // ─── User Routes ──────────────────────────────────────────
      GoRoute(path: AppRoutes.home, builder: (c, s) => const HomeScreen()),
      GoRoute(
        path: AppRoutes.uploadResume,
        builder: (c, s) => const UploadResumeScreen(),
      ),
      GoRoute(
        path: AppRoutes.atsChecker,
        builder: (c, s) => const AtsCheckerScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (c, s) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.jobSelection,
        builder: (c, s) => const JobSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.analysisResult,
        builder: (c, s) {
          final analysisId = s.pathParameters['analysisId'] ?? '';
          return AnalysisResultScreen(analysisId: analysisId);
        },
      ),

      // ─── Admin / Recruiter Routes ─────────────────────────────
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (c, s) => const AdminMainScreen(),
        routes: [
          GoRoute(
            path: 'job-creation',
            builder: (c, s) => const JobCreationScreen(),
          ),
          // Vacancy applicants — pushed from the vacancies tab
          GoRoute(
            path: 'vacancy/:jobId',
            builder: (c, s) {
              final jobId = s.pathParameters['jobId'] ?? '';
              return VacancyApplicantsScreen(jobId: jobId);
            },
          ),
          GoRoute(
            path: 'candidates/:candidateId',
            builder: (c, s) {
              final candidateId = s.pathParameters['candidateId'] ?? '';
              return CandidateDetailScreen(candidateId: candidateId);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Route not found: ${state.error}'))),
  );
});

class AppRoutes {
  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role-selection';

  // User
  static const String home = '/home';
  static const String uploadResume = '/upload-resume';
  static const String atsChecker = '/ats-checker';
  static const String profile = '/profile';
  static const String jobSelection = '/job-selection';
  static const String analysisResult = '/analysis/:analysisId';

  // Recruiter (admin) — sub-routes are relative to /admin
  static const String adminDashboard = '/admin';
  static const String jobCreation = '/admin/job-creation';
  static const String vacancyApplicants = '/admin/vacancy/:jobId';
  static const String candidateDetail = '/admin/candidates/:candidateId';

  // Helpers
  static String analysisResultWithId(String id) => '/analysis/$id';
  static String vacancyApplicantsWithId(String jobId) =>
      '/admin/vacancy/$jobId';
  static String candidateDetailWithId(String id) => '/admin/candidates/$id';
}
