import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/firebase_service.dart';
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
  return service.getUser(firebaseUser.uid);
});

// ─── Auth State ───────────────────────────────────────────────────────────────
class AuthState {
  final bool isLoading;
  final bool isGoogleLoading;
  final String? error;
  final UserModel? user;

  const AuthState({
    this.isLoading = false,
    this.isGoogleLoading = false,
    this.error,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isGoogleLoading,
    String? error,
    UserModel? user,
  }) => AuthState(
    isLoading: isLoading ?? this.isLoading,
    isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
    error: error, // explicit null clears previous error
    user: user ?? this.user,
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
      state = state.copyWith(isLoading: false, user: user);
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
  Future<UserModel?> signInWithGoogle() async {
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
      }

      state = state.copyWith(isGoogleLoading: false, user: user);

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
