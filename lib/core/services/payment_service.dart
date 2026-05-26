import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'email_service.dart';

// Mobile-only — conditional import prevents web crash
import 'package:razorpay_flutter/razorpay_flutter.dart'
    if (dart.library.html) 'razorpay_web_stub.dart';

// JS bridge: dart:js_interop on web, no-op stub on mobile
import 'payment_js_bridge.dart'
    if (dart.library.io) 'payment_js_bridge_stub.dart'
    as bridge;

// ─── Payment Plans ────────────────────────────────────────────────────────────

enum PaymentPlan { fixResume, jdOptimize, bundle, humanReview, resumeGenerator }

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
    }
  }
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

// ─── Payment Service ──────────────────────────────────────────────────────────

class PaymentService {
  static String get _backendUrl => AppConfig.backendUrl;
  static String get _keyId => AppConfig.razorpayKeyId;

  Razorpay? _razorpay;

  // ── Step 1: Create order via backend ────────────────────────────────────────
  Future<Map<String, dynamic>?> _createOrder(PaymentPlan plan) async {
    final url = '$_backendUrl/api/payment/create-order';
    debugPrint('[PAY] _createOrder → POST $url  plan=${plan.planKey}');

    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
        'amount': plan.amountInPaise,
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

  const PaywallSheet({
    super.key,
    required this.plan,
    required this.userEmail,
    required this.userName,
    required this.onSuccess,
  });

  static Future<bool> show(
    BuildContext context, {
    required PaymentPlan plan,
    required String userEmail,
    required String userName,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallSheet(
        plan: plan,
        userEmail: userEmail,
        userName: userName,
        onSuccess: () => Navigator.of(context).pop(true),
      ),
    );
    return result ?? false;
  }

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  final _paymentService = PaymentService();
  bool _loading = false;
  String? _error;

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
        amount: widget.plan.displayPrice,
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
                        'Unlock for ${plan.displayPrice}',
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
          ],
        ),
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
    }
  }
}
