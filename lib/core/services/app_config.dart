// lib/core/services/app_config.dart
//
// All config values come from --dart-define at build time.
// They are baked into the compiled binary — no .env file loading, no 404 errors.
//
// HOW TO BUILD:
//   flutter build web --release \
//     --dart-define=BACKEND_URL=https://resume-ai-backend-bwzx.onrender.com \
//     --dart-define=RAZORPAY_KEY_ID=rzp_test_xxx \
//     --dart-define=ADMIN_EMAIL=you@gmail.com \
//     --dart-define=ADMIN_NAME=Vishesh \
//     --dart-define=EMAILJS_PUBLIC_KEY=xxx \
//     --dart-define=EMAILJS_SERVICE_ID=service_xxx \
//     --dart-define=EMAILJS_TEMPLATE_ID=template_xxx \
//     --dart-define=EMAILJS_HUMAN_REVIEW_TEMPLATE_ID=template_xxx
//
// VS Code: add all --dart-define lines to .vscode/launch.json toolArgs.

class AppConfig {
  AppConfig._();

  // ── Backend ───────────────────────────────────────────────────────────────
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://resume-ai-backend-bwzx.onrender.com',
  );

  // ── Razorpay (public key — safe in binary) ────────────────────────────────
  static const razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const adminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: '',
  );
  static const adminName = String.fromEnvironment(
    'ADMIN_NAME',
    defaultValue: 'Admin',
  );

  // ── EmailJS ───────────────────────────────────────────────────────────────
  static const emailJsPublicKey = String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
    defaultValue: '',
  );
  static const emailJsServiceId = String.fromEnvironment(
    'EMAILJS_SERVICE_ID',
    defaultValue: '',
  );
  static const emailJsTemplateId = String.fromEnvironment(
    'EMAILJS_TEMPLATE_ID',
    defaultValue: '',
  );
  static const emailJsHumanReviewTemplateId = String.fromEnvironment(
    'EMAILJS_HUMAN_REVIEW_TEMPLATE_ID',
    defaultValue: '',
  );

  // ── Validation (call at startup to catch missing keys early) ──────────────
  static bool get isEmailConfigured =>
      emailJsPublicKey.isNotEmpty &&
      emailJsServiceId.isNotEmpty &&
      emailJsTemplateId.isNotEmpty;

  static bool get isPaymentConfigured =>
      razorpayKeyId.isNotEmpty && backendUrl.isNotEmpty;

  static void validate() {
    final missing = <String>[];
    if (backendUrl.isEmpty) missing.add('BACKEND_URL');
    if (razorpayKeyId.isEmpty) missing.add('RAZORPAY_KEY_ID');
    if (adminEmail.isEmpty) missing.add('ADMIN_EMAIL');
    if (emailJsPublicKey.isEmpty) missing.add('EMAILJS_PUBLIC_KEY');
    if (emailJsServiceId.isEmpty) missing.add('EMAILJS_SERVICE_ID');
    if (emailJsTemplateId.isEmpty) missing.add('EMAILJS_TEMPLATE_ID');

    if (missing.isNotEmpty) {
      // ignore: avoid_print
      print('[AppConfig] Missing --dart-define keys: ${missing.join(', ')}');
    }
  }
}
