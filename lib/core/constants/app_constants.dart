class AppConstants {
  static const String appName = 'AI Resume Analyzer';
  static const String appVersion = '1.0.0';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String jobsCollection = 'jobs';
  static const String resumesCollection = 'resumes';
  static const String analysisCollection = 'analysis';
  static const String adminDecisionsCollection = 'admin_decisions';

  // Referral Program — Phase 1 (live now)
  // Slim public-readable lookup: {code} -> {uid}. Kept separate from
  // `users` so validating a code never requires broad read access to
  // user documents.
  static const String referralCodesCollection = 'referral_codes';
  // Audit trail of referral actions (signup linked, purchase credited,
  // refund reversed, etc.) — spec requires storing all referral events.
  static const String referralEventsCollection = 'referral_events';

  // Referral Program — Phase 2 (live on the backend now; not yet read
  // directly by the Flutter client — see ReferralService for the
  // /quote and /wallet endpoints that expose this data instead)
  static const String purchasesCollection = 'purchases';
  static const String referralTransactionsCollection = 'referral_transactions';
  static const String campaignConfigCollection = 'config';
  static const String campaignConfigDocId = 'referral_campaign';

  // Referral Program — Phase 4 (withdrawals, not wired yet)
  static const String withdrawalRequestsCollection = 'withdrawal_requests';

  // Referral Program — fallback discount shown in share/promo copy on
  // screens that don't load the live wallet summary (so they don't need an
  // extra network call just to render a share button). Keep this in sync
  // with DEFAULT_CONFIG.discountPercent in the backend's referralEngine.js —
  // it's only a display fallback; the real number is always enforced
  // server-side at checkout.
  static const int defaultReferralDiscountPercent = 10;

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
