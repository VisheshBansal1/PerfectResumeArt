import 'dart:convert';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/auth_gate.dart';
import 'app_config.dart';
import 'auth_token_helper.dart';
import 'email_service.dart';

// Mobile-only — conditional import prevents web crash
import 'package:razorpay_flutter/razorpay_flutter.dart'
    if (dart.library.html) 'razorpay_web_stub.dart';

// JS bridge: dart:js_interop on web, no-op stub on mobile
import 'payment_js_bridge.dart'
    if (dart.library.io) 'payment_js_bridge_stub.dart'
    as bridge;

// AdMob rewarded ads — app-only. On web this resolves to a no-op stub, so
// the "watch an ad" option never appears there and purchase stays the only
// path (see ad_service_web_stub.dart).
import 'ad_service.dart' if (dart.library.html) 'ad_service_web_stub.dart';

// ─── Payment Plans ────────────────────────────────────────────────────────────

enum PaymentPlan {
  fixResume,
  jdOptimize,
  bundle,
  humanReview,
  resumeGenerator,
  interviewPrep,
}

extension PaymentPlanX on PaymentPlan {
  String get title {
    switch (this) {
      case PaymentPlan.fixResume:
        return 'Fix My Resume';
      case PaymentPlan.jdOptimize:
        return 'JD Optimization';
      case PaymentPlan.bundle:
        return 'Full Upgrade Bundle';
      case PaymentPlan.humanReview:
        return 'Expert Human Review';
      case PaymentPlan.resumeGenerator:
        return 'AI Resume Builder';
      case PaymentPlan.interviewPrep:
        return 'Interview Prep Report';
    }
  }

  int get amountInPaise {
    switch (this) {
      case PaymentPlan.fixResume:
        return 3900;
      case PaymentPlan.jdOptimize:
        return 4900;
      case PaymentPlan.bundle:
        return 7900; // ₹79 — clear saving vs ₹39+₹49+₹49+₹129=₹266
      case PaymentPlan.humanReview:
        return 12900;
      case PaymentPlan.resumeGenerator:
        return 4900; // ₹49
      case PaymentPlan.interviewPrep:
        return 3900; // ₹39
    }
  }

  // Plan key must match backend VALID_PLANS in validate.js
  String get planKey {
    switch (this) {
      case PaymentPlan.fixResume:
        return 'fixResume';
      case PaymentPlan.jdOptimize:
        return 'jdOptimize';
      case PaymentPlan.bundle:
        return 'bundle';
      case PaymentPlan.humanReview:
        return 'humanReview';
      case PaymentPlan.resumeGenerator:
        return 'resumeGenerator';
      case PaymentPlan.interviewPrep:
        return 'interviewPrep';
    }
  }

  String get displayPrice {
    switch (this) {
      case PaymentPlan.fixResume:
        return '₹39';
      case PaymentPlan.jdOptimize:
        return '₹49';
      case PaymentPlan.bundle:
        return '₹79';
      case PaymentPlan.humanReview:
        return '₹129';
      case PaymentPlan.resumeGenerator:
        return '₹49';
      case PaymentPlan.interviewPrep:
        return '₹39';
    }
  }

  String get description {
    switch (this) {
      case PaymentPlan.fixResume:
        return 'Rewritten bullets + stronger summary + impact metrics + PDF download';
      case PaymentPlan.jdOptimize:
        return 'Resume auto-adjusted to match job description keywords';
      case PaymentPlan.bundle:
        return 'Fix Resume + JD Optimization + ATS Boost + PDF Download';
      case PaymentPlan.humanReview:
        return 'Expert manually reviews and rewrites your resume in 24 hrs';
      case PaymentPlan.resumeGenerator:
        return 'AI builds a complete professional resume from your info + PDF download';
      case PaymentPlan.interviewPrep:
        return 'Full 20-question interview Q&A tailored to this resume + job, with a downloadable PDF';
    }
  }
}

// ─── Pricing Quote (Referral Program) ─────────────────────────────────────────
// What the paywall sheet shows BEFORE checkout — computed by the same
// backend logic that sets the actual Razorpay order amount, so this never
// drifts from what's actually charged.
class PricingQuote {
  final double originalAmount; // ₹
  final double finalAmount; // ₹ — what will actually be charged
  final int discountPercent;
  final bool eligible;

  const PricingQuote({
    required this.originalAmount,
    required this.finalAmount,
    required this.discountPercent,
    required this.eligible,
  });

  factory PricingQuote.fromJson(
    Map<String, dynamic> json,
    double fallbackAmount,
  ) {
    return PricingQuote(
      originalAmount:
          (json['originalAmount'] as num?)?.toDouble() ?? fallbackAmount,
      finalAmount: (json['finalAmount'] as num?)?.toDouble() ?? fallbackAmount,
      discountPercent: json['discountPercent'] as int? ?? 0,
      eligible: json['eligible'] == true,
    );
  }

  // Safe default if the quote request fails — full price, no discount.
  factory PricingQuote.fallback(double amount) => PricingQuote(
    originalAmount: amount,
    finalAmount: amount,
    discountPercent: 0,
    eligible: false,
  );

  String get finalAmountDisplay =>
      '\u20b9${finalAmount.toStringAsFixed(finalAmount.truncateToDouble() == finalAmount ? 0 : 2)}';
  String get originalAmountDisplay =>
      '\u20b9${originalAmount.toStringAsFixed(originalAmount.truncateToDouble() == originalAmount ? 0 : 2)}';
}

// ─── Payment Result ───────────────────────────────────────────────────────────

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? error;
  const PaymentResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.error,
  });
}

// ─── Paywall Outcome ──────────────────────────────────────────────────────────
// What PaywallSheet.show(...) resolved to. Callers must branch on this
// instead of a plain bool so a genuine (persisted, forever) purchase is
// never confused with a one-time rewarded-ad unlock:
//   • purchased  → persist the unlock in Firestore via unlockProvider, same
//                  as before.
//   • watchedAd  → grant this ONE use of the feature only (a local/session
//                  flag in the calling screen) — never write it to
//                  Firestore or the unlockProvider, or it would silently
//                  become a permanent free unlock.
//   • cancelled  → user backed out (or isn't signed in) — do nothing.
enum PaywallResult { cancelled, purchased, watchedAd }

// ─── Payment Service ──────────────────────────────────────────────────────────

class PaymentService {
  static String get _backendUrl => AppConfig.backendUrl;
  static String get _keyId => AppConfig.razorpayKeyId;

  Razorpay? _razorpay;

  // Attaches the signed-in user's Firebase ID token when available, so the
  // backend can check referral eligibility. Never throws — checkout must
  // keep working (at full price) even if this fails for any reason.
  Future<Map<String, String>> _authHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    try {
      final token = await getIdTokenSafely();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    } catch (e) {
      debugPrint(
        '[PAY] Could not attach auth token (continuing without it): $e',
      );
    }
    return headers;
  }

  // ── Pricing preview — call before the user taps "Pay" ──────────────────────
  Future<PricingQuote> getQuote(PaymentPlan plan) async {
    final fallback = plan.amountInPaise / 100;
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('$_backendUrl/api/referral/quote?plan=${plan.planKey}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return PricingQuote.fallback(fallback);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PricingQuote.fromJson(data, fallback);
    } catch (e) {
      debugPrint('[PAY] getQuote failed, falling back to full price: $e');
      return PricingQuote.fallback(fallback);
    }
  }

  // ── Step 1: Create order via backend ────────────────────────────────────────
  Future<Map<String, dynamic>?> _createOrder(PaymentPlan plan) async {
    final url = '$_backendUrl/api/payment/create-order';
    debugPrint('[PAY] _createOrder → POST $url  plan=${plan.planKey}');

    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(url),
        headers: await _authHeaders(),
        body: jsonEncode({'plan': plan.planKey}),
      );
    } catch (e) {
      debugPrint('[PAY] _createOrder network error: $e');
      throw Exception(
        'Network error — is BACKEND_URL correct?\nURL tried: $url\nError: $e',
      );
    }

    debugPrint(
      '[PAY] _createOrder response ${response.statusCode}: ${response.body}',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('[PAY] Order created: ${data['order_id']}');
      return data;
    }

    String errorMsg = 'Server error ${response.statusCode}';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      errorMsg = body['error']?.toString() ?? errorMsg;
    } catch (_) {}
    throw Exception(errorMsg);
  }

  // ── Step 2 (Web): Verify payment via backend ─────────────────────────────
  Future<bool> _verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    debugPrint('[PAY] _verifyPayment → order=$orderId payment=$paymentId');
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/payment/verify-payment'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        }),
      );
      debugPrint(
        '[PAY] _verifyPayment response ${response.statusCode}: ${response.body}',
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['success'] == true;
    } catch (e) {
      debugPrint('[PAY] _verifyPayment error: $e');
      return false;
    }
  }

  // ── Main entry ──────────────────────────────────────────────────────────────
  Future<void> startPayment({
    required PaymentPlan plan,
    required String userEmail,
    required String userName,
    required Function(PaymentResult) onResult,
  }) async {
    if (kIsWeb) {
      await _startWebPayment(
        plan: plan,
        userEmail: userEmail,
        userName: userName,
        onResult: onResult,
      );
    } else {
      await _startMobilePayment(
        plan: plan,
        userEmail: userEmail,
        userName: userName,
        onResult: onResult,
      );
    }
  }

  // ── WEB: Backend order → JS bridge → Checkout.js → Backend verify ──────────
  //
  // KEY FIX: js.JsObject.jsify() cannot handle Dart function values.
  // So we split the flow into two JS calls:
  //   1. registerRazorpayCallbacks(onSuccess, onDismiss) — registers Dart fns
  //   2. openRazorpayCheckout(key, orderId, ...) — only scalar values, safe to pass
  // The JS in index.html builds the full options object and wires callbacks.
  Future<void> _startWebPayment({
    required PaymentPlan plan,
    required String userEmail,
    required String userName,
    required Function(PaymentResult) onResult,
  }) async {
    try {
      // Step 1: Create order via backend
      final orderData = await _createOrder(plan);
      if (orderData == null || orderData['success'] != true) {
        onResult(
          const PaymentResult(
            success: false,
            error: 'Could not create payment order. Check BACKEND_URL in .env',
          ),
        );
        return;
      }

      final orderId = orderData['order_id'] as String;
      final amount = orderData['amount'] as int;
      final keyId = (orderData['key_id'] as String?)?.isNotEmpty == true
          ? orderData['key_id'] as String
          : _keyId;

      final completer = Completer<PaymentResult>();

      debugPrint('[PAY] Step 2: register JS callbacks via bridge');
      // Step 2: use dart:js_interop bridge (dart:js is deprecated in Dart 3)
      bridge.registerRazorpayCallbacks(
        onSuccess:
            (String paymentId, String rzpOrderId, String signature) async {
              debugPrint('[PAY] JS onSuccess: paymentId=$paymentId');
              if (completer.isCompleted) return;
              try {
                final verified = await _verifyPayment(
                  orderId: orderId,
                  paymentId: paymentId,
                  signature: signature,
                );
                completer.complete(
                  PaymentResult(
                    success: verified,
                    paymentId: paymentId,
                    orderId: orderId,
                    error: verified
                        ? null
                        : 'Payment verification failed. Contact support.',
                  ),
                );
              } catch (e) {
                completer.complete(
                  PaymentResult(
                    success: false,
                    error: 'Verification error: $e',
                  ),
                );
              }
            },
        onDismiss: () {
          debugPrint('[PAY] JS onDismiss called');
          if (!completer.isCompleted) {
            completer.complete(
              const PaymentResult(success: false, error: 'Payment cancelled'),
            );
          }
        },
      );

      debugPrint(
        '[PAY] Step 3: open Razorpay checkout — key=$keyId orderId=$orderId amount=$amount',
      );
      // Step 3: scalar values only — bridge handles JS interop
      bridge.openRazorpayCheckout(
        keyId: keyId,
        orderId: orderId,
        amount: amount,
        currency: 'INR',
        name: 'Resume AI',
        description: plan.description,
        userEmail: userEmail,
        userName: userName,
      );

      debugPrint('[PAY] Waiting for Razorpay callback (max 5 min)...');

      // Timeout on completer — if Razorpay modal opens but callbacks
      // never fire (rare edge case), we don't hang forever
      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('[PAY] completer timed out — no callback received');
          return const PaymentResult(
            success: false,
            error: 'Payment session expired. Please try again.',
          );
        },
      );

      debugPrint(
        '[PAY] completer resolved: success=${result.success} error=${result.error}',
      );
      onResult(result);
    } catch (e) {
      debugPrint('[PAY] _startWebPayment caught: $e');
      onResult(PaymentResult(success: false, error: e.toString()));
    }
  }

  // ── MOBILE: Backend order → Native plugin ───────────────────────────────────
  Future<void> _startMobilePayment({
    required PaymentPlan plan,
    required String userEmail,
    required String userName,
    required Function(PaymentResult) onResult,
  }) async {
    if (_keyId.isEmpty) {
      onResult(
        const PaymentResult(
          success: false,
          error: 'RAZORPAY_KEY_ID not set in .env',
        ),
      );
      return;
    }
    try {
      final orderData = await _createOrder(plan);
      if (orderData == null || orderData['success'] != true) {
        onResult(
          const PaymentResult(
            success: false,
            error: 'Could not create payment order',
          ),
        );
        return;
      }
      final orderId = orderData['order_id'] as String;
      // FIX: use the amount Razorpay actually charges (order-authoritative,
      // may be discounted) — NOT plan.amountInPaise, which is always the
      // undiscounted sticker price and would mismatch a referral discount.
      final amount = orderData['amount'] as int;

      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        onResult(
          PaymentResult(
            success: true,
            paymentId: r.paymentId,
            orderId: r.orderId,
          ),
        );
        _disposeRazorpay();
      });
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        onResult(PaymentResult(success: false, error: r.message));
        _disposeRazorpay();
      });
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
        onResult(
          const PaymentResult(
            success: false,
            error: 'External wallet selected',
          ),
        );
        _disposeRazorpay();
      });
      _razorpay!.open({
        'key': _keyId,
        'amount': amount,
        'currency': 'INR',
        'order_id': orderId,
        'name': 'Resume AI',
        'description': plan.description,
        'prefill': {'name': userName, 'email': userEmail, 'contact': ''},
        'theme': {'color': '#2D5BE3'},
      });
    } catch (e) {
      onResult(PaymentResult(success: false, error: e.toString()));
      _disposeRazorpay();
    }
  }

  void _disposeRazorpay() {
    _razorpay?.clear();
    _razorpay = null;
  }
}

// ─── Paywall Bottom Sheet ─────────────────────────────────────────────────────

class PaywallSheet extends StatefulWidget {
  final PaymentPlan plan;
  final String userEmail;
  final String userName;
  final VoidCallback onSuccess;

  /// Whether the "watch an ad instead" option is offered for this plan.
  /// Defaults to true. Set to false for plans that shouldn't be given away
  /// for one ad view — e.g. PaymentPlan.humanReview (a real person does
  /// manual work to fulfill it) or PaymentPlan.bundle (permanently unlocks
  /// every paid feature at once, including human review).
  final bool allowAdUnlock;

  const PaywallSheet({
    super.key,
    required this.plan,
    required this.userEmail,
    required this.userName,
    required this.onSuccess,
    this.allowAdUnlock = true,
  });

  static Future<PaywallResult> show(
    BuildContext context, {
    required PaymentPlan plan,
    required String userEmail,
    required String userName,
    bool allowAdUnlock = true,
  }) async {
    // Hard gate on the payment entry point itself — not at each call site.
    // Every "Unlock"/"Buy" button across every premium screen calls this
    // one static method, so checking here means neither a purchase nor a
    // rewarded-ad unlock can start without a signed-in user, regardless of
    // which screen (existing or future) triggers it.
    if (FirebaseAuth.instance.currentUser == null) {
      if (!context.mounted) return PaywallResult.cancelled;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SignInRequiredSheet(feature: plan.title),
      );
      return PaywallResult.cancelled;
    }

    final result = await showModalBottomSheet<PaywallResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallSheet(
        plan: plan,
        userEmail: userEmail,
        userName: userName,
        allowAdUnlock: allowAdUnlock,
        onSuccess: () => Navigator.of(context).pop(PaywallResult.purchased),
      ),
    );
    return result ?? PaywallResult.cancelled;
  }

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  final _paymentService = PaymentService();
  bool _loading = false;
  bool _adLoading = false;
  String? _error;

  PricingQuote? _quote;

  // Only offered on app builds — AdService.isSupported is false on web.
  bool get _showAdOption => widget.allowAdUnlock && AdService.isSupported;

  @override
  void initState() {
    super.initState();
    _loadQuote();
    // Warm up a rewarded ad the moment the sheet opens so it's ready by the
    // time the user taps the button.
    if (_showAdOption) AdService.instance.loadRewardedAd();
  }

  Future<void> _watchAd() async {
    setState(() {
      _adLoading = true;
      _error = null;
    });
    try {
      final earned = await AdService.instance.showRewardedAd();
      if (!mounted) return;
      setState(() => _adLoading = false);
      if (earned) {
        Navigator.of(context).pop(PaywallResult.watchedAd);
      } else {
        setState(
          () => _error =
              'Ad not available right now. Please try again in a moment, '
              'or unlock with payment instead.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adLoading = false;
        _error = 'Could not show ad: $e';
      });
    }
  }

  Future<void> _loadQuote() async {
    final quote = await _paymentService.getQuote(widget.plan);
    if (mounted) setState(() => _quote = quote);
  }

  Future<void> _pay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    debugPrint('[PAY] _pay() started — plan=${widget.plan.planKey}');

    try {
      await _paymentService.startPayment(
        plan: widget.plan,
        userEmail: widget.userEmail,
        userName: widget.userName,
        onResult: (result) async {
          debugPrint(
            '[PAY] onResult called — success=${result.success} error=${result.error}',
          );
          if (!mounted) return;
          setState(() => _loading = false);

          if (result.success) {
            // ── Send confirmation email ONLY after verified payment success ──
            // This is the correct integration point:
            //   • Razorpay has returned success (mobile) OR
            //   • Backend /api/payment/verify-payment returned { success: true }
            // Do NOT call this before onResult, or on payment failure.
            await _sendConfirmationEmail();

            widget.onSuccess();
          } else {
            setState(
              () =>
                  _error = result.error ?? 'Payment failed. Please try again.',
            );
          }
        },
      );
    } catch (e) {
      debugPrint('[PAY] _pay() uncaught: $e');
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    } finally {
      // Safety net — ensure spinner always stops
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  /// Sends a payment confirmation email via EmailJS and shows a snackbar
  /// with the result. Non-fatal — a failure here never blocks the unlock flow.
  Future<void> _sendConfirmationEmail() async {
    try {
      await EmailService.instance.sendPaymentSuccessEmail(
        userName: widget.userName,
        userEmail: widget.userEmail,
        planName: widget.plan.title,
        amount: (_quote?.eligible == true)
            ? _quote!.finalAmountDisplay
            : widget.plan.displayPrice,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Confirmation email sent'),
            backgroundColor: Color(0xFF43A047),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on EmailServiceException catch (e) {
      debugPrint('[PAY] Confirmation email failed (non-fatal): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Failed to send confirmation email'),
            backgroundColor: Color(0xFFE53935),
            duration: Duration(seconds: 3),
          ),
        );
      }
      // Do NOT rethrow — email failure must never block the unlock.
    } catch (e) {
      debugPrint('[PAY] Unexpected email error (non-fatal): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Failed to send confirmation email'),
            backgroundColor: Color(0xFFE53935),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2D5BE3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: Color(0xFF2D5BE3),
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              plan.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              plan.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ..._features(plan).map(
              (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF43A047),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(f, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildPricingRow(),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 13,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5BE3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Unlock for ${(_quote?.eligible == true) ? _quote!.finalAmountDisplay : plan.displayPrice}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '🔒 Secure payment via Razorpay · One-time · No subscription',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
            if (_showAdOption) ..._buildAdOption(),
          ],
        ),
      ),
    );
  }

  // ── "Or watch an ad instead" ────────────────────────────────────────────
  // App-only free alternative to paying. Grants this ONE use of the
  // feature, not a permanent unlock — see PaywallResult docs.
  List<Widget> _buildAdOption() {
    return [
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'OR',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: (_loading || _adLoading) ? null : _watchAd,
          icon: _adLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_circle_outline_rounded, size: 20),
          label: Text(
            _adLoading ? 'Loading ad…' : 'Watch an ad to use this — free',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2D5BE3),
            side: const BorderSide(color: Color(0xFF2D5BE3), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Free one-time use of this feature · No account or purchase needed',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
    ];
  }

  // Referral Program — shows Original Price / Discount / Final Price with a
  // "Launch Partner Discount Applied" badge when the signed-in user is a
  // referred first-time buyer during an active campaign. Renders nothing
  // (not even a placeholder) when there's no discount, so the sheet looks
  // exactly as it always has for everyone else.
  Widget _buildPricingRow() {
    final quote = _quote;
    if (quote == null || !quote.eligible) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF43A047).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF43A047).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_offer, color: Color(0xFF43A047), size: 16),
              const SizedBox(width: 6),
              Text(
                'Launch Partner Discount Applied',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                quote.originalAmountDisplay,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${quote.discountPercent}% OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                quote.finalAmountDisplay,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _features(PaymentPlan plan) {
    switch (plan) {
      case PaymentPlan.fixResume:
        return [
          'All bullets rewritten with action verbs + metrics',
          'Professional summary rewrite',
          'Impact added to every project',
          'Download as ATS-friendly PDF',
          'Before vs After view',
        ];
      case PaymentPlan.jdOptimize:
        return [
          'JD keywords automatically embedded',
          'Resume language aligned to job posting',
          'ATS score estimate boost shown',
          'Download optimized resume as PDF',
        ];
      case PaymentPlan.bundle:
        return [
          '✨ Fix Resume (bullets + summary + impact)',
          '🎯 JD Optimization (keywords + ATS boost)',
          '📄 PDF Download (clean formatted)',
          '🔍 Before vs After view',
          'Best value — save ₹39',
        ];
      case PaymentPlan.humanReview:
        return [
          'Expert resume writer manually reviews',
          'Full rewrite with personalized feedback',
          'Delivered in 24 hours via email',
          'One free revision included',
          'LinkedIn headline bonus tip',
        ];
      case PaymentPlan.resumeGenerator:
        return [
          'Complete AI-generated professional resume',
          'ATS-optimized bullets with action verbs + metrics',
          'PDF download (ready to apply)',
          'Top 10 ATS keywords for your target role',
          '4 best-fit job role suggestions',
          '🔗 LinkedIn About section (bonus)',
        ];
      case PaymentPlan.interviewPrep:
        return [
          'All 20 interview questions unlocked (5 already shown)',
          'HR, Technical, Coding, Behavioural, Project & Resume-based rounds',
          'Model answers written from your actual resume',
          'Final recruiter advice for this specific role',
          '📄 Download the complete report as PDF',
        ];
    }
  }
}
