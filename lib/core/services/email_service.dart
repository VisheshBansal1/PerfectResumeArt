import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// HOW TO SET ENVIRONMENT VARIABLES (--dart-define)
// ─────────────────────────────────────────────────────────────────────────────
//
// Flutter does NOT read .env files at compile time for const values.
// Instead, pass secrets via --dart-define when building / running:
//
//   flutter run \
//     --dart-define=EMAILJS_PUBLIC_KEY=your_public_key \
//     --dart-define=EMAILJS_SERVICE_ID=service_xxxxxxx \
//     --dart-define=EMAILJS_TEMPLATE_ID=template_xxxxxxx
//
//   flutter build apk \
//     --dart-define=EMAILJS_PUBLIC_KEY=your_public_key \
//     --dart-define=EMAILJS_SERVICE_ID=service_xxxxxxx \
//     --dart-define=EMAILJS_TEMPLATE_ID=template_xxxxxxx
//
// In VS Code, add to .vscode/launch.json:
//   "toolArgs": [
//     "--dart-define=EMAILJS_PUBLIC_KEY=your_key",
//     "--dart-define=EMAILJS_SERVICE_ID=service_xxx",
//     "--dart-define=EMAILJS_TEMPLATE_ID=template_xxx"
//   ]
//
// In CI/CD (GitHub Actions / Codemagic / Bitrise), add as environment secrets
// and pass them using the --dart-define flag in your build command.
//
// ─── Why NOT dotenv for secrets? ─────────────────────────────────────────────
// dotenv reads from an asset file shipped inside the APK — anyone can unzip
// the APK and read it. --dart-define bakes values into the compiled binary,
// making extraction significantly harder.
//
// ─── Where to get your EmailJS credentials ───────────────────────────────────
// 1. Sign up at https://www.emailjs.com (free tier: 200 emails/month)
// 2. Add an Email Service (Gmail / Outlook / SMTP)  → copy Service ID
// 3. Create an Email Template with these variables:
//      {{name}}, {{email}}, {{plan}}, {{amount}}, {{admin_name}}
//    → copy Template ID
// 4. Account → API Keys → copy Public Key
// ─────────────────────────────────────────────────────────────────────────────

/// Reads EmailJS credentials baked in at compile time via --dart-define.
/// Falls back to empty string — validated in [EmailService.isConfigured].
const _kPublicKey = String.fromEnvironment('EMAILJS_PUBLIC_KEY');
const _kServiceId = String.fromEnvironment('EMAILJS_SERVICE_ID');
const _kTemplateId = String.fromEnvironment('EMAILJS_TEMPLATE_ID');

/// Reusable EmailJS service for sending transactional emails.
///
/// Currently supports:
///   • [sendPaymentSuccessEmail] — triggers after successful Razorpay payment.
///
/// To add more email types, create a new template on EmailJS and add a
/// corresponding method here that calls [_send] with different template params.
class EmailService {
  EmailService._();
  static final EmailService instance = EmailService._();

  // EmailJS public REST endpoint — no backend needed.
  static const _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  // ── Config guard ─────────────────────────────────────────────────────────────
  /// Returns true when all three --dart-define values were provided at build.
  /// Call this before sending to give a clear error rather than a silent failure.
  bool get isConfigured =>
      _kPublicKey.isNotEmpty &&
      _kServiceId.isNotEmpty &&
      _kTemplateId.isNotEmpty;

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Sends a payment confirmation email to the user.
  ///
  /// Call this ONLY after:
  ///   1. Razorpay fires [Razorpay.EVENT_PAYMENT_SUCCESS] (mobile), OR
  ///   2. Your backend's /api/payment/verify-payment returns { success: true }
  ///
  /// Example (inside PaywallSheet._pay() onResult callback):
  /// ```dart
  /// if (result.success) {
  ///   await EmailService.instance.sendPaymentSuccessEmail(
  ///     userName:  widget.userName,
  ///     userEmail: widget.userEmail,
  ///     planName:  widget.plan.title,
  ///     amount:    widget.plan.displayPrice,
  ///   );
  ///   widget.onSuccess();
  /// }
  /// ```
  Future<void> sendPaymentSuccessEmail({
    required String userName,
    required String userEmail,
    required String planName,
    required String amount,
  }) async {
    debugPrint('[EMAIL] sendPaymentSuccessEmail → $userEmail  plan=$planName');

    await _send(
      templateParams: {
        // These keys must match your EmailJS template variables exactly.
        'name': userName.trim().isEmpty ? 'User' : userName.trim(),
        'email': userEmail.trim(),
        'plan': planName,
        'amount': amount,
        'admin_name': 'Vishesh',
      },
    );
  }

  // ── Low-level sender ──────────────────────────────────────────────────────────

  /// Posts to the EmailJS REST API.
  /// Throws [EmailServiceException] on any non-200 response or network error.
  Future<void> _send({required Map<String, String> templateParams}) async {
    if (!isConfigured) {
      const msg =
          '[EMAIL] ⚠️  EmailJS not configured — pass --dart-define=EMAILJS_PUBLIC_KEY=... '
          'EMAILJS_SERVICE_ID=... EMAILJS_TEMPLATE_ID=... when building.';
      debugPrint(msg);
      throw const EmailServiceException(msg);
    }

    final payload = jsonEncode({
      'service_id': _kServiceId,
      'template_id': _kTemplateId,
      'user_id': _kPublicKey,      // EmailJS calls their public key "user_id"
      'template_params': templateParams,
    });

    debugPrint('[EMAIL] POST $_apiUrl');
    debugPrint('[EMAIL] template_params: $templateParams');

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              // EmailJS requires this origin header for CORS on their public API
              'origin': 'http://localhost',
            },
            body: payload,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const EmailServiceException(
              'EmailJS request timed out after 15 s',
            ),
          );
    } on EmailServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[EMAIL] network error: $e');
      throw EmailServiceException('Network error: $e');
    }

    debugPrint('[EMAIL] response ${response.statusCode}: ${response.body}');

    // EmailJS returns HTTP 200 with body "OK" on success.
    if (response.statusCode == 200) {
      debugPrint('[EMAIL] ✅ Email sent successfully');
      return;
    }

    // Non-200 → parse error body if possible
    String detail = response.body;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      detail = json['message']?.toString() ?? detail;
    } catch (_) {}

    debugPrint('[EMAIL] ❌ EmailJS error ${response.statusCode}: $detail');
    throw EmailServiceException(
      'EmailJS returned ${response.statusCode}: $detail',
    );
  }
}

// ─── Exception type ───────────────────────────────────────────────────────────

/// Thrown by [EmailService] on any failure.
/// Callers should catch this and show a snackbar rather than crashing.
class EmailServiceException implements Exception {
  final String message;
  const EmailServiceException(this.message);

  @override
  String toString() => 'EmailServiceException: $message';
}
