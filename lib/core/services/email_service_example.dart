// ─────────────────────────────────────────────────────────────────────────────
// EXAMPLE: Complete payment + email confirmation flow
//
// This file is a reference — it is NOT imported anywhere in the app.
// It shows exactly how EmailService hooks into the payment lifecycle.
//
// The actual integration lives in:
//   lib/core/services/payment_service.dart → _PaywallSheetState
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:next_hire/core/services/email_service.dart';
import 'package:next_hire/core/services/payment_service.dart';

// ─── Scenario 1: Through PaywallSheet (recommended — already integrated) ─────
//
// PaywallSheet is the single paywall entry point used throughout the app.
// EmailService is already wired inside _PaywallSheetState._pay().
// Simply call PaywallSheet.show() from any screen — the email fires automatically.
//
// Example from fix_resume_screen.dart:
//
//   final unlocked = await PaywallSheet.show(
//     context,
//     plan:      PaymentPlan.fixResume,
//     userEmail: widget.userEmail,
//     userName:  widget.userName,
//   );
//   if (unlocked) {
//     // Email already sent inside PaywallSheet — nothing else needed here.
//     _startResumeImprovement();
//   }

// ─── Scenario 2: Manual trigger (if you bypass PaywallSheet) ─────────────────
//
// Only needed if you launch Razorpay directly (not through PaywallSheet).
// Guard: call email ONLY after backend verify-payment returns { success: true }.

class ManualPaymentExample extends StatefulWidget {
  final String userEmail;
  final String userName;
  const ManualPaymentExample({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<ManualPaymentExample> createState() => _ManualPaymentExampleState();
}

class _ManualPaymentExampleState extends State<ManualPaymentExample> {
  final _paymentService = PaymentService();

  Future<void> _handlePayment() async {
    await _paymentService.startPayment(
      plan: PaymentPlan.fixResume,
      userEmail: widget.userEmail,
      userName: widget.userName,
      onResult: (PaymentResult result) async {
        if (!mounted) return;

        if (result.success) {
          // ── STEP A: Unlock the feature in Firestore ──────────────────────
          // (handled by your existing unlock provider)

          // ── STEP B: Send confirmation email ─────────────────────────────
          //
          // Call ONLY here — after result.success == true.
          // Never call on failure, cancel, or before this callback fires.
          //
          await _sendEmailAndNotify(
            planName: PaymentPlan.fixResume.title,
            amount: PaymentPlan.fixResume.displayPrice,
          );

          // ── STEP C: Navigate / unlock UI ─────────────────────────────────
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          // Show error — do NOT send email on failure
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.error ?? 'Payment failed')),
            );
          }
        }
      },
    );
  }

  Future<void> _sendEmailAndNotify({
    required String planName,
    required String amount,
  }) async {
    try {
      // EmailService reads keys from --dart-define at compile time.
      // No runtime config needed — just call it.
      await EmailService.instance.sendPaymentSuccessEmail(
        userName: widget.userName,
        userEmail: widget.userEmail,
        planName: planName,
        amount: amount,
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
      // Non-fatal — log and warn, never block the unlock.
      debugPrint('[EXAMPLE] Email failed (non-fatal): $e');
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
    return ElevatedButton(
      onPressed: _handlePayment,
      child: const Text('Pay ₹39'),
    );
  }
}

// ─── Scenario 3: Testing EmailService in isolation (unit / debug) ─────────────
//
// Run this from a debug button or in a test to verify your EmailJS config
// without going through a real payment flow.
//
// Future<void> testEmailDirectly(BuildContext context) async {
//   try {
//     await EmailService.instance.sendPaymentSuccessEmail(
//       userName:  'Test User',
//       userEmail: 'your@email.com',   // ← use your own email to verify receipt
//       planName:  'Fix My Resume',
//       amount:    '₹39',
//     );
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('✅ Test email sent — check your inbox')),
//     );
//   } on EmailServiceException catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('❌ Email failed: ${e.message}')),
//     );
//   }
// }
//
// Common failures and fixes:
//   401  → wrong EMAILJS_PUBLIC_KEY — check --dart-define value
//   400  → wrong service/template ID — verify in EmailJS dashboard
//   403  → domain not whitelisted — add 'localhost' in EmailJS allowed origins
//   Timeout → network issue or EmailJS is down
