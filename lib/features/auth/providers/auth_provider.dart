import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/referral_service.dart';
import '../../../models/models.dart';

// ─── Firebase service ─────────────────────────────────────────────────────────
final firebaseServiceProvider = Provider<FirebaseService>(
  (_) => FirebaseService(),
);

// ─── Auth stream ──────────────────────────────────────────────────────────────
// Emits the raw Firebase user whenever sign-in state changes.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ─── Current user profile ─────────────────────────────────────────────────────
// FIX: Use ref.watch(authStateProvider) correctly inside FutureProvider.
// Riverpod re-runs this provider whenever authStateProvider emits a new value.
// Using ref.watch() (not ref.read()) here is intentional and correct —
// it makes currentUserProvider re-execute when auth changes.
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  // Watch auth state — re-runs this provider when user signs in/out.
  final authValue = ref.watch(authStateProvider);

  final firebaseUser = authValue.when(
    data: (u) => u,
    loading: () => null,
    error: (_, __) => null,
  );

  if (firebaseUser == null) return null;

  // Try to load existing Firestore profile.
  final service = ref.read(firebaseServiceProvider);
  var user = await service.getUser(firebaseUser.uid);
  if (user == null) return null;

  // Referral Program: retry any attach that failed the first time around.
  // The one case this actually fires for: Google's popup sign-in resolves
  // FirebaseAuth's current-user state slightly slower than email/password
  // signup does, so the very first attach attempt (right after account
  // creation) could momentarily have no token to work with and fail. That
  // failure no longer discards the pending code (see referral_service.dart),
  // so it's still sitting in local storage — try it again here, now that
  // auth state is unquestionably settled. No-ops harmlessly (no network
  // call at all) if there's nothing pending or this account is already
  // linked to a referrer.
  if (user.referredBy == null) {
    final attached = await ReferralService().attachAfterSignup();
    if (attached) {
      user = await service.getUser(firebaseUser.uid) ?? user;
    }
  }

  // Referral Program: every user gets a permanent shareable code. Generated
  // lazily here so it covers both brand-new signups and every account that
  // existed before this feature shipped — no separate migration needed.
  if (user.referralCode == null || user.referralCode!.isEmpty) {
    final code = await ReferralService().ensureReferralCode(
      uid: user.uid,
      name: user.name,
      existingCode: user.referralCode,
    );
    return user.copyWith(referralCode: code);
  }

  return user;
});

// ─── Auth State ───────────────────────────────────────────────────────────────
class AuthState {
  final bool isLoading;
  final bool isGoogleLoading;
  final String? error;
  final UserModel? user;
  // 'attached' | 'failed' | null (null = no referral code was involved at
  // all in this sign-in — the normal case, nothing to report).
  final String? referralAttachResult;

  const AuthState({
    this.isLoading = false,
    this.isGoogleLoading = false,
    this.error,
    this.user,
    this.referralAttachResult,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isGoogleLoading,
    String? error,
    UserModel? user,
    String? referralAttachResult,
  }) => AuthState(
    isLoading: isLoading ?? this.isLoading,
    isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
    error: error, // explicit null clears previous error
    user: user ?? this.user,
    referralAttachResult: referralAttachResult, // explicit null clears previous result, same pattern as error
  );
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref.read(firebaseServiceProvider), ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._service, this._ref) : super(const AuthState());

  final Ref _ref;

  final FirebaseService _service;
  final _auth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn(
    clientId:
        '714792558226-3psg4f1obo97f2l9jn652mac6uajpesg.apps.googleusercontent.com',
  );

  // ── Email/Password register ───────────────────────────────────────────────
  Future<UserModel?> register({
    required String email,
    required String password,
    required String name,
    String? referralCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user!.updateDisplayName(name);

      final user = UserModel(
        uid: cred.user!.uid,
        email: email,
        name: name,
        role: 'user',
        createdAt: DateTime.now(),
      );
      await _service.createUser(user);

      // Best-effort — never blocks account creation if this fails. Uses
      // cred.user's own token directly (same pattern as Google sign-in)
      // rather than depending on FirebaseAuth's global current-user state.
      String? freshToken;
      try {
        freshToken = await cred.user!.getIdToken();
      } catch (e) {
        debugPrint('[Auth] Could not get token for referral attach: $e');
      }

      String? attachResult;
      final codeInvolved = referralCode != null && referralCode.trim().isNotEmpty;
      if (codeInvolved) {
        final attached = await ReferralService().attachAfterSignup(
          explicitCode: referralCode,
          explicitToken: freshToken,
        );
        attachResult = attached ? 'attached' : 'failed';
      }

      state = state.copyWith(isLoading: false, user: user, referralAttachResult: attachResult);
      return user;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
      return null;
    }
  }

  // ── Email/Password login ──────────────────────────────────────────────────
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = await _service.getUser(cred.user!.uid);
      state = state.copyWith(isLoading: false, user: user);
      return user;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
      return null;
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<UserModel?> signInWithGoogle({String? explicitReferralCode}) async {
    state = state.copyWith(isGoogleLoading: true, error: null);

    try {
      final googleProvider = GoogleAuthProvider();

      googleProvider.setCustomParameters({'prompt': 'select_account'});

      final userCredential = await _auth.signInWithPopup(googleProvider);

      final fbUser = userCredential.user;

      if (fbUser == null) {
        state = state.copyWith(isGoogleLoading: false);

        return null;
      }

      UserModel? user = await _service.getUser(fbUser.uid);
      String? referralResult;

      if (user == null) {
        user = UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ?? 'User',
          photoUrl: fbUser.photoURL,
          role: 'user',
          createdAt: DateTime.now(),
        );

        await _service.createUser(user);

        // FIX: get the token directly from fbUser — it's the concrete,
        // already-resolved User object this sign-in call just returned, so
        // there's no dependency on FirebaseAuth.instance's global current-
        // user state (or any stream) having caught up yet. Only for
        // brand-new accounts — never re-attaches on a returning user's
        // later logins.
        String? freshToken;
        try {
          freshToken = await fbUser.getIdToken();
        } catch (e) {
          debugPrint('[Auth] Could not get fbUser token for referral attach: $e');
        }

        final hasExplicitCode = explicitReferralCode != null && explicitReferralCode.trim().isNotEmpty;
        final pendingCode = hasExplicitCode ? null : await ReferralService().getPendingReferralCode();
        final codeInvolved = hasExplicitCode || (pendingCode != null && pendingCode.isNotEmpty);

        if (codeInvolved) {
          final attached = await ReferralService().attachAfterSignup(
            explicitCode: explicitReferralCode,
            explicitToken: freshToken,
          );
          referralResult = attached ? 'attached' : 'failed';
        }
      }

      state = state.copyWith(isGoogleLoading: false, user: user, referralAttachResult: referralResult);

      return user;
    } catch (e, stackTrace) {
      debugPrint('Google Sign-In Error: $e');

      debugPrintStack(stackTrace: stackTrace);

      state = state.copyWith(isGoogleLoading: false, error: e.toString());

      return null;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);

    // FIX 2: Invalidate currentUserProvider so that when another account logs in,
    // providers that watch(currentUserProvider) or watch(authStateProvider) will
    // automatically re-run and fetch fresh data for the new user.
    // The authStateProvider (a StreamProvider on Firebase) emits the new user
    // automatically; this ensures the cached FutureProvider is also cleared.
    _ref.invalidate(currentUserProvider);

    state = const AuthState();
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'account-exists-with-different-credential':
        return 'This email is linked to a different sign-in method.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}