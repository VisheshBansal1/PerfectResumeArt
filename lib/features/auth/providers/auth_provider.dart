import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/services/firebase_service.dart';
import '../../../models/models.dart';

// ─── Providers ────────────────────────────────────────────────
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = ref.watch(authStateProvider).when(
  data: (user) => user,
  loading: () => null,
  error: (_, __) => null,
);
  if (user == null) return null;
  final service = ref.read(firebaseServiceProvider);
  return service.getUser(user.uid);
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(firebaseServiceProvider));
});

// ─── State ────────────────────────────────────────────────────
class AuthState {
  final bool isLoading;
  final String? error;
  final UserModel? user;

  const AuthState({this.isLoading = false, this.error, this.user});

  AuthState copyWith({bool? isLoading, String? error, UserModel? user}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        user: user ?? this.user,
      );
}

// ─── Notifier ─────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseService _service;
  final _auth = FirebaseAuth.instance;

  AuthNotifier(this._service) : super(const AuthState());

  Future<UserModel?> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user!.updateDisplayName(name);

      final user = UserModel(
        uid: credential.user!.uid,
        email: email,
        name: name,
        role: role,
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

  Future<UserModel?> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = await _service.getUser(credential.user!.uid);
      state = state.copyWith(isLoading: false, user: user);
      return user;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    state = const AuthState();
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
