class AppConstants {
  static const String appName = 'AI Resume Analyzer';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String jobsCollection = 'jobs';
  static const String resumesCollection = 'resumes';
  static const String analysisCollection = 'analysis';
  static const String adminDecisionsCollection = 'admin_decisions';

  // Storage Paths
  static const String resumeStoragePath = 'resumes';

  // Roles
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';

  // AI Model
  static const String geminiModel = 'Groq';

  // Decision Types
  static const String decisionPass = 'Pass';
  static const String decisionFail = 'Fail';
  static const String decisionHighPotential = 'High Potential';

  // Score Thresholds
  static const int excellentScore = 80;
  static const int goodScore = 60;
  static const int averageScore = 40;
}

class AppStrings {
  static const String loginTitle = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to your account';
  static const String registerTitle = 'Create Account';
  static const String registerSubtitle = 'Join as a candidate or recruiter';
  static const String uploadResumeTitle = 'Upload Resume';
  static const String analysisTitle = 'Resume Analysis';
  static const String jobSelectionTitle = 'Select Job Role';
  static const String adminDashboardTitle = 'Admin Dashboard';
}
