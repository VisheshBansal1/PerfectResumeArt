import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/error_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter_riverpod/legacy.dart';

import '../core/services/resume_improve_service.dart'; // GeneratedResume, ExperienceEntry, ProjectEntry
import '../core/services/resume_pdf_service.dart';
import '../core/services/payment_service.dart';

// ─── Service Providers ────────────────────────────────────────────────────────

final resumeImproveServiceProvider = Provider<ResumeImproveService>(
  (_) => ResumeImproveService(),
);

final resumePdfServiceProvider = Provider<ResumePdfService>(
  (_) => ResumePdfService(),
);

// ─── Unlock Status Provider ───────────────────────────────────────────────────
// Persists unlocks to Firestore so they survive app restarts.
//
// BUG FIX: The original UnlockNotifier called _load() in its constructor, but
// on web (especially after auth-persistence fix) the Firebase user is not ready
// yet at that moment — _uid returns null and the load is silently skipped.
// Fix: listen to Firebase auth state changes and reload whenever a user signs in.

class UnlockNotifier extends StateNotifier<Set<String>> {
  UnlockNotifier() : super({}) {
    // Listen to auth state — reload purchases each time a user signs in.
    // This covers: app cold-start, page refresh (web), and account switching.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _load(user.uid);
      } else {
        // User signed out — clear in-memory unlocks immediately.
        state = {};
      }
    });
  }

  final _db = FirebaseFirestore.instance;
  late final StreamSubscription<User?> _authSub;

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _load(String uid) async {
    try {
      final doc = await _db.collection('unlocks').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final plans = (data['plans'] as List? ?? []).cast<String>().toSet();
        state = plans;
      } else {
        state = {}; // New user — no purchases yet
      }
    } catch (_) {}
  }

  Future<void> unlock(String planKey) async {
    // Update in-memory state immediately so the UI reflects the purchase at once
    state = {...state, planKey};
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Use FieldValue.arrayUnion so concurrent calls don't overwrite each other
      await _db.collection('unlocks').doc(uid).set({
        'plans': FieldValue.arrayUnion([planKey]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge:true never wipes existing plans
    } catch (_) {}
  }

  bool isUnlocked(String planKey) => state.contains(planKey);
}

final unlockProvider = StateNotifierProvider<UnlockNotifier, Set<String>>(
  (_) => UnlockNotifier(),
);

// ─── Fix Resume State ─────────────────────────────────────────────────────────

class FixResumeState {
  final bool isLoading;
  final ImprovedResume? result;
  final String? error;
  final String? pdfPath;
  final bool isGeneratingPdf;

  const FixResumeState({
    this.isLoading = false,
    this.result,
    this.error,
    this.pdfPath,
    this.isGeneratingPdf = false,
  });

  FixResumeState copyWith({
    bool? isLoading,
    ImprovedResume? result,
    Object? error = _keep,
    String? pdfPath,
    bool? isGeneratingPdf,
  }) => FixResumeState(
    isLoading: isLoading ?? this.isLoading,
    result: result ?? this.result,
    error: error == _keep ? this.error : error as String?,
    pdfPath: pdfPath ?? this.pdfPath,
    isGeneratingPdf: isGeneratingPdf ?? this.isGeneratingPdf,
  );
}

const _keep = Object();

class FixResumeNotifier extends StateNotifier<FixResumeState> {
  final ResumeImproveService _service;
  final ResumePdfService _pdfService;

  FixResumeNotifier(this._service, this._pdfService)
    : super(const FixResumeState());

  Future<void> fix({required String resumeText, String jobTitle = ''}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.fixResume(
        resumeText: resumeText,
        jobTitle: jobTitle,
      );
      state = state.copyWith(isLoading: false, result: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
    }
  }

  Future<void> generatePdf({
    required String resumeText,
    required String name,
  }) async {
    state = state.copyWith(isGeneratingPdf: true);
    try {
      final path = await _pdfService.generatePdf(
        resumeText: resumeText,
        fileName: '${name.replaceAll(' ', '_')}_improved_resume',
      );
      state = state.copyWith(isGeneratingPdf: false, pdfPath: path);
    } catch (e) {
      state = state.copyWith(isGeneratingPdf: false, error: friendlyError(e));
    }
  }

  void reset() => state = const FixResumeState();
}

final fixResumeProvider =
    StateNotifierProvider.autoDispose<FixResumeNotifier, FixResumeState>((ref) {
      return FixResumeNotifier(
        ref.read(resumeImproveServiceProvider),
        ref.read(resumePdfServiceProvider),
      );
    });

// ─── JD Optimize State ────────────────────────────────────────────────────────

class JdOptimizeState {
  final bool isLoading;
  final JdOptimizedResume? result;
  final String? error;
  final String? pdfPath;
  final bool isGeneratingPdf;

  const JdOptimizeState({
    this.isLoading = false,
    this.result,
    this.error,
    this.pdfPath,
    this.isGeneratingPdf = false,
  });

  JdOptimizeState copyWith({
    bool? isLoading,
    JdOptimizedResume? result,
    Object? error = _keep,
    String? pdfPath,
    bool? isGeneratingPdf,
  }) => JdOptimizeState(
    isLoading: isLoading ?? this.isLoading,
    result: result ?? this.result,
    error: error == _keep ? this.error : error as String?,
    pdfPath: pdfPath ?? this.pdfPath,
    isGeneratingPdf: isGeneratingPdf ?? this.isGeneratingPdf,
  );
}

class JdOptimizeNotifier extends StateNotifier<JdOptimizeState> {
  final ResumeImproveService _service;
  final ResumePdfService _pdfService;

  JdOptimizeNotifier(this._service, this._pdfService)
    : super(const JdOptimizeState());

  Future<void> optimize({
    required String resumeText,
    required String jobDescription,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.optimizeWithJD(
        resumeText: resumeText,
        jobDescription: jobDescription,
      );
      state = state.copyWith(isLoading: false, result: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
    }
  }

  Future<void> generatePdf({
    required String resumeText,
    required String name,
  }) async {
    state = state.copyWith(isGeneratingPdf: true);
    try {
      final path = await _pdfService.generatePdf(
        resumeText: resumeText,
        fileName: '${name.replaceAll(' ', '_')}_jd_optimized_resume',
      );
      state = state.copyWith(isGeneratingPdf: false, pdfPath: path);
    } catch (e) {
      state = state.copyWith(isGeneratingPdf: false, error: friendlyError(e));
    }
  }

  void reset() => state = const JdOptimizeState();
}

final jdOptimizeProvider =
    StateNotifierProvider.autoDispose<JdOptimizeNotifier, JdOptimizeState>((
      ref,
    ) {
      return JdOptimizeNotifier(
        ref.read(resumeImproveServiceProvider),
        ref.read(resumePdfServiceProvider),
      );
    });

// ─── Rejection Reasons State ──────────────────────────────────────────────────

class RejectionState {
  final bool isLoading;
  final List<RejectionReason> reasons;
  final String? error;

  const RejectionState({
    this.isLoading = false,
    this.reasons = const [],
    this.error,
  });
}

class RejectionNotifier extends StateNotifier<RejectionState> {
  final ResumeImproveService _service;
  RejectionNotifier(this._service) : super(const RejectionState());

  Future<void> analyze({
    required String resumeText,
    String jobTitle = '',
  }) async {
    state = const RejectionState(isLoading: true);
    try {
      final reasons = await _service.getWhyRejected(
        resumeText: resumeText,
        jobTitle: jobTitle,
      );
      state = RejectionState(reasons: reasons);
    } catch (e) {
      state = RejectionState(error: friendlyError(e));
    }
  }

  void reset() => state = const RejectionState();
}

final rejectionProvider =
    StateNotifierProvider.autoDispose<RejectionNotifier, RejectionState>((ref) {
      return RejectionNotifier(ref.read(resumeImproveServiceProvider));
    });

// ─── Project Improver State ───────────────────────────────────────────────────

class ProjectImproveState {
  final bool isLoading;
  final ImprovedProject? result;
  final String? error;

  const ProjectImproveState({this.isLoading = false, this.result, this.error});
}

class ProjectImproveNotifier extends StateNotifier<ProjectImproveState> {
  final ResumeImproveService _service;
  ProjectImproveNotifier(this._service) : super(const ProjectImproveState());

  Future<void> improve({required String line, String context = ''}) async {
    state = const ProjectImproveState(isLoading: true);
    try {
      final result = await _service.improveProjectLine(
        projectLine: line,
        context: context,
      );
      state = ProjectImproveState(result: result);
    } catch (e) {
      state = ProjectImproveState(error: friendlyError(e));
    }
  }

  void reset() => state = const ProjectImproveState();
}

final projectImproveProvider =
    StateNotifierProvider.autoDispose<
      ProjectImproveNotifier,
      ProjectImproveState
    >((ref) => ProjectImproveNotifier(ref.read(resumeImproveServiceProvider)));

// ─── Selection Booster State ──────────────────────────────────────────────────

class SelectionBoosterState {
  final bool isLoading;
  final SelectionBooster? result;
  final String? error;

  const SelectionBoosterState({
    this.isLoading = false,
    this.result,
    this.error,
  });
}

class SelectionBoosterNotifier extends StateNotifier<SelectionBoosterState> {
  final ResumeImproveService _service;
  SelectionBoosterNotifier(this._service)
    : super(const SelectionBoosterState());

  Future<void> analyze({
    required String resumeText,
    String jobTitle = '',
  }) async {
    state = const SelectionBoosterState(isLoading: true);
    try {
      final result = await _service.getSelectionBoosters(
        resumeText: resumeText,
        jobTitle: jobTitle,
      );
      state = SelectionBoosterState(result: result);
    } catch (e) {
      state = SelectionBoosterState(error: friendlyError(e));
    }
  }

  void setError(String message) {
    state = SelectionBoosterState(error: message);
  }
}

final selectionBoosterProvider =
    StateNotifierProvider.autoDispose<
      SelectionBoosterNotifier,
      SelectionBoosterState
    >(
      (ref) => SelectionBoosterNotifier(ref.read(resumeImproveServiceProvider)),
    );

// ─── Resume Generator State ───────────────────────────────────────────────────

class ResumeGeneratorState {
  final bool isLoading;
  final GeneratedResume? result;
  final String? error;
  final String? pdfPath;
  final bool isGeneratingPdf;

  const ResumeGeneratorState({
    this.isLoading = false,
    this.result,
    this.error,
    this.pdfPath,
    this.isGeneratingPdf = false,
  });

  ResumeGeneratorState copyWith({
    bool? isLoading,
    GeneratedResume? result,
    Object? error = _keep,
    String? pdfPath,
    bool? isGeneratingPdf,
  }) => ResumeGeneratorState(
    isLoading: isLoading ?? this.isLoading,
    result: result ?? this.result,
    error: error == _keep ? this.error : error as String?,
    pdfPath: pdfPath ?? this.pdfPath,
    isGeneratingPdf: isGeneratingPdf ?? this.isGeneratingPdf,
  );
}

class ResumeGeneratorNotifier extends StateNotifier<ResumeGeneratorState> {
  final ResumeImproveService _service;
  final ResumePdfService _pdfService;

  ResumeGeneratorNotifier(this._service, this._pdfService)
    : super(const ResumeGeneratorState());

  Future<void> generate({
    required String fullName,
    required String email,
    required String phone,
    required String location,
    required String targetRole,
    required String yearsExp,
    required List<ExperienceEntry> experiences,
    required String education,
    required String skills,
    required List<ProjectEntry> projects,
    String existingResumeText = '',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.generateResume(
        fullName: fullName,
        email: email,
        phone: phone,
        location: location,
        targetRole: targetRole,
        yearsExp: yearsExp,
        experiences: experiences,
        education: education,
        skills: skills,
        projects: projects,
        existingResumeText: existingResumeText,
      );
      state = state.copyWith(isLoading: false, result: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyError(e));
    }
  }

  Future<void> generatePdf({required String name}) async {
    final text = state.result?.resumeText;
    if (text == null) return;
    state = state.copyWith(isGeneratingPdf: true);
    try {
      final path = await _pdfService.generatePdf(
        resumeText: text,
        fileName: '${name.replaceAll(' ', '_')}_AI_resume',
      );
      state = state.copyWith(isGeneratingPdf: false, pdfPath: path);
    } catch (e) {
      state = state.copyWith(isGeneratingPdf: false, error: friendlyError(e));
    }
  }

  void reset() => state = const ResumeGeneratorState();
}

final resumeGeneratorProvider =
    StateNotifierProvider.autoDispose<
      ResumeGeneratorNotifier,
      ResumeGeneratorState
    >(
      (ref) => ResumeGeneratorNotifier(
        ref.read(resumeImproveServiceProvider),
        ref.read(resumePdfServiceProvider),
      ),
    );
