import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:next_hire/features/auth/widgets/auth_widget.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  bool _obscure        = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _navigate(String role) {
    if (role == 'admin') {
      context.go(AppRoutes.adminDashboard);
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final user = await ref.read(authNotifierProvider.notifier).login(
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (user != null && mounted) _navigate(user.role);
  }

  Future<void> _googleSignIn() async {
    final user = await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle();
    if (user != null && mounted) _navigate(user.role);
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

              // ── Google Sign-In (primary, fastest) ─────────────
              GoogleSignInButton(
                isLoading: authState.isGoogleLoading,
                onTap: authState.isGoogleLoading || authState.isLoading
                    ? null
                    : _googleSignIn,
              ),
              const SizedBox(height: 20),

              // ── Divider ───────────────────────────────────────
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or sign in with email',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
                const Expanded(child: Divider()),
              ]),
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.document_scanner_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          const Text('Welcome back',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Sign in to analyze and improve your resume',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey[600], height: 1.4)),
        ],
      );

  Widget _buildForm() => Form(
        key: _formKey,
        child: Column(children: [
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
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => v == null || v.length < 6
                ? 'Password must be 6+ characters'
                : null,
          ),
        ]),
      );

  Widget _buildLoginButton(AuthState authState) => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed:
              authState.isLoading || authState.isGoogleLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: authState.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Sign In',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _buildRegisterLink() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Don't have an account? ",
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          GestureDetector(
            onTap: () => context.push(AppRoutes.register),
            child: Text('Create one',
                style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      );
}