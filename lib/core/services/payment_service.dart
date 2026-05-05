import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

enum PaymentPlan {
  fixResume,      // ₹39
  jdOptimize,     // ₹49
  bundle,         // ₹89
  humanReview,    // ₹129
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
    }
  }

  int get amountInPaise {
    switch (this) {
      case PaymentPlan.fixResume:
        return 3900; // ₹39
      case PaymentPlan.jdOptimize:
        return 4900; // ₹49
      case PaymentPlan.bundle:
        return 8900; // ₹89
      case PaymentPlan.humanReview:
        return 12900; // ₹129
    }
  }

  String get displayPrice {
    switch (this) {
      case PaymentPlan.fixResume:
        return '₹39';
      case PaymentPlan.jdOptimize:
        return '₹49';
      case PaymentPlan.bundle:
        return '₹89';
      case PaymentPlan.humanReview:
        return '₹129';
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
    }
  }
}

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? error;

  const PaymentResult({required this.success, this.paymentId, this.error});
}

/// Razorpay payment service for real INR payments.
/// Requires RAZORPAY_KEY_ID in .env
class PaymentService {
  static String get _keyId => dotenv.env['RAZORPAY_KEY_ID'] ?? '';

  Razorpay? _razorpay;
  Function(PaymentResult)? _onResult;

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    _onResult?.call(PaymentResult(success: true, paymentId: response.paymentId));
    _dispose();
  }

  void _handleError(PaymentFailureResponse response) {
    _onResult?.call(PaymentResult(success: false, error: response.message));
    _dispose();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _onResult?.call(PaymentResult(success: false, error: 'External wallet selected'));
    _dispose();
  }

  void _dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _onResult = null;
  }

  /// Opens Razorpay checkout for the given plan.
  /// Returns a [PaymentResult] via the callback.
  Future<void> startPayment({
    required PaymentPlan plan,
    required String userEmail,
    required String userName,
    required Function(PaymentResult) onResult,
  }) async {
    // Razorpay native SDK does not support Flutter Web
    if (kIsWeb) {
      onResult(const PaymentResult(
        success: false,
        error: 'Payments are only supported in the mobile app. Please download the app to unlock premium features.',
      ));
      return;
    }

    if (_keyId.isEmpty) {
      onResult(const PaymentResult(
        success: false,
        error: 'Razorpay key not configured. Add RAZORPAY_KEY_ID to .env',
      ));
      return;
    }

    _initRazorpay();
    _onResult = onResult;

    final options = {
      'key': _keyId,
      'amount': plan.amountInPaise,
      'currency': 'INR',
      'name': 'ResumeAI',
      'description': plan.description,
      'prefill': {
        'name': userName,
        'email': userEmail,
        'contact': '',
      },
      'theme': {'color': '#2D5BE3'},
      'modal': {
        'confirm_close': true,
        'animation': true,
      },
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      onResult(PaymentResult(success: false, error: e.toString()));
      _dispose();
    }
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
    setState(() { _loading = true; _error = null; });

    await _paymentService.startPayment(
      plan: widget.plan,
      userEmail: widget.userEmail,
      userName: widget.userName,
      onResult: (result) {
        if (!mounted) return;
        setState(() => _loading = false);
        if (result.success) {
          widget.onSuccess();
        } else {
          setState(() => _error = result.error ?? 'Payment failed. Please try again.');
        }
      },
    );
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
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Lock icon + title
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2D5BE3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_open_rounded, color: Color(0xFF2D5BE3), size: 28),
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
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 20),
            // Feature list
            ..._features(plan).map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Color(0xFF43A047), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
              ]),
            )),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFE53935), fontSize: 13)),
              ),
            // Pay button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _pay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5BE3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        'Unlock for ${plan.displayPrice}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '🔒 Secure payment via Razorpay · One-time · No subscription',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
    }
  }
}
