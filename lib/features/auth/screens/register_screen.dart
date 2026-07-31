import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:next_hire/features/auth/widgets/auth_widget.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/referral_service.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  bool _obscure = true;

  // ── Referral Program ────────────────────────────────────────────────────
  bool _referralFromLink = false; // pre-filled from a ?ref= link vs typed in
  bool _referralChecking = false;
  ReferralValidation? _referralResult;
  Timer? _referralDebounce;

  @override
  void initState() {
    super.initState();
    _prefillReferralFromLink();
  }

  Future<void> _prefillReferralFromLink() async {
    final code = await ReferralService().getPendingReferralCode();
    if (code == null || !mounted) return;
    setState(() {
      _referralCtrl.text = code;
      _referralFromLink = true;
    });
    _checkReferralCode(code);
  }

  void _onReferralChanged(String value) {
    // Typing manually overrides the "came from a link" badge.
    if (_referralFromLink) setState(() => _referralFromLink = false);
    _referralDebounce?.cancel();
    _referralResult = null;
    if (value.trim().isEmpty) {
      setState(() {});
      return;
    }
    _referralDebounce = Timer(const Duration(milliseconds: 500), () {
      _checkReferralCode(value.trim());
    });
  }

  Future<void> _checkReferralCode(String code) async {
    if (code.isEmpty) return;
    setState(() => _referralChecking = true);
    final result = await ReferralService().validateCode(code);
    if (!mounted) return;
    setState(() {
      _referralChecking = false;
      _referralResult = result;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _referralCtrl.dispose();
    _referralDebounce?.cancel();
    super.dispose();
  }

  // Shows a clear, explicit result — never silent about whether a referral
  // code actually attached. Called right before navigating away.
  void _showReferralFeedback() {
    final result = ref.read(authNotifierProvider).referralAttachResult;
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result == 'attached' ? AppTheme.success : AppTheme.error,
        content: Text(
          result == 'attached'
              ? '🎉 Referral code applied — you\u2019re all set!'
              : 'Couldn\u2019t apply that referral code. You can try again from your Profile.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final user = await ref
        .read(authNotifierProvider.notifier)
        .register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: _nameCtrl.text.trim(),
          referralCode: _referralCtrl.text.trim().isEmpty
              ? null
              : _referralCtrl.text.trim(),
        );
    if (user == null || !mounted) return;
    _showReferralFeedback();
    context.go(AppRoutes.home);
  }

  Future<void> _googleSignIn() async {
    final user = await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle(
          explicitReferralCode: _referralCtrl.text.trim().isEmpty
              ? null
              : _referralCtrl.text.trim(),
        );
    if (user == null || !mounted) return;
    _showReferralFeedback();
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Google Sign-Up (fastest path) ─────────────────
            const Text(
              'Quickest way to get started:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            GoogleSignInButton(
              isLoading: authState.isGoogleLoading,
              onTap: authState.isGoogleLoading || authState.isLoading
                  ? null
                  : _googleSignIn,
            ),
            const SizedBox(height: 20),

            // ── Divider ───────────────────────────────────────
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or register with email',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 20),

            // ── Email form ────────────────────────────────────
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter your name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 6
                        ? 'Minimum 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _referralCtrl,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: _onReferralChanged,
                    decoration: InputDecoration(
                      labelText: 'Referral code (optional)',
                      prefixIcon: const Icon(Icons.card_giftcard_outlined),
                      suffixIcon: _referralChecking
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (_referralResult?.valid == true
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null),
                      helperText: _referralFromLink
                          ? 'Applied from your invite link'
                          : 'Have a friend\'s code? Enter it for a launch discount.',
                      errorText: (_referralResult != null && !_referralResult!.valid)
                          ? _referralResult!.error
                          : null,
                    ),
                  ),
                  if (_referralResult?.valid == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Referred by ${_referralResult!.referrerName}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Submit ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: authState.isLoading || authState.isGoogleLoading
                    ? null
                    : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            if (authState.error != null) ...[
              const SizedBox(height: 12),
              AuthErrorBanner(authState.error!),
            ],

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => context.go(AppRoutes.login),
                  child: Text(
                    'Sign in',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Alias kept for any existing router references ─────────────────────────
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});
  @override
  Widget build(BuildContext context) => const RegisterScreen();
}