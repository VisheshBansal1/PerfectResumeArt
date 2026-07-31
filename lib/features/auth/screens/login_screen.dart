// lib/features/auth/screens/login_screen.dart
//
// CHANGES vs original (search for "// ← NEW" to find every change):
//   1. Added import for GuestPreviewScreen
//   2. Added _buildGuestLink() method
//   3. Called _buildGuestLink() in the Column, below _buildRegisterLink()

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:next_hire/features/auth/widgets/auth_widget.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/referral_service.dart';
import '../../../features/resume/screens/guest_preview_screen.dart'; // ← NEW
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  bool _obscure = true;
  // Always available regardless of link/no-link — starts expanded and
  // pre-filled only if a code was actually detected; otherwise collapsed,
  // but the user can still open it and type one in themselves.
  bool _referralExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkPendingReferral();
  }

  Future<void> _checkPendingReferral() async {
    final code = await ReferralService().getPendingReferralCode();
    if (code == null || !mounted) return;
    setState(() {
      _referralCtrl.text = code;
      _referralExpanded = true;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  void _navigate(String role) {
    if (role == 'admin') {
      context.go(AppRoutes.adminDashboard);
    } else {
      context.go(AppRoutes.home);
    }
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final user = await ref
        .read(authNotifierProvider.notifier)
        .login(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    if (user != null && mounted) _navigate(user.role);
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
    _navigate(user.role);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              _buildHeader(),
              const SizedBox(height: 32),

              // ── Referral code — always available, whether the person
              // came from a link or not. Auto-expanded and pre-filled if
              // one was detected; otherwise collapsed but always reachable.
              _buildReferralSection(),
              const SizedBox(height: 16),

              // ── Google Sign-In (primary, fastest) ─────────────
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
                      'or sign in with email',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),

              // ── Email / Password ──────────────────────────────
              _buildForm(),
              const SizedBox(height: 16),
              _buildLoginButton(authState),

              if (authState.error != null) ...[
                const SizedBox(height: 12),
                AuthErrorBanner(authState.error!),
              ],

              const SizedBox(height: 24),
              _buildRegisterLink(),

              // ← NEW: Guest preview entry point
              const SizedBox(height: 16),
              _buildGuestLink(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralSection() => Container(
    decoration: BoxDecoration(
      color: AppTheme.accent.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _referralExpanded = !_referralExpanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _referralCtrl.text.trim().isNotEmpty
                        ? 'Referral code: ${_referralCtrl.text.trim()}'
                        : 'Have a referral code?',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.accent),
                  ),
                ),
                Icon(
                  _referralExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppTheme.accent,
                ),
              ],
            ),
          ),
        ),
        if (_referralExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _referralCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => setState(() {}), // keep the collapsed-header preview in sync
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Enter code (optional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Applied automatically when you sign in with Google. Leave blank if you don\u2019t have one.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.document_scanner_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Welcome back',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        'Sign in to analyze and improve your resume',
        style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.4),
      ),
    ],
  );

  Widget _buildForm() => Form(
    key: _formKey,
    child: Column(
      children: [
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (v) =>
              v == null || !v.contains('@') ? 'Enter a valid email' : null,
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
              ? 'Password must be 6+ characters'
              : null,
        ),
      ],
    ),
  );

  Widget _buildLoginButton(AuthState authState) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: authState.isLoading || authState.isGoogleLoading
          ? null
          : _login,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              'Sign In',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
    ),
  );

  Widget _buildRegisterLink() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        "Don't have an account? ",
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
      GestureDetector(
        onTap: () => context.push(AppRoutes.register),
        child: Text(
          'Create one',
          style: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );

  // ← NEW: Opens GuestPreviewScreen as a full-screen modal slide-up
  Widget _buildGuestLink() => Column(
    children: [
      // Divider with label
      Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'not ready to sign up?',
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
      const SizedBox(height: 12),

      // Guest button — full width, outlined, subtle
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GuestPreviewScreen(),
                // slide up from bottom like a sheet
                fullscreenDialog: true,
              ),
            );
          },
          icon: const Text('⚡', style: TextStyle(fontSize: 15)),
          label: const Text('Try Without Signup — Free ATS Preview'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: BorderSide(color: AppTheme.borderLight),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ],
  );
}