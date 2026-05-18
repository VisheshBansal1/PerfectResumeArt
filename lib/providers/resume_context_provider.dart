// lib/providers/resume_context_provider.dart
//
// Single source of truth for the user's current resume.
// Persisted to Firestore so it survives navigation and app restarts.
// Populated when: ATS check runs, Full analysis runs, or manual upload.
// Read by: ALL premium features — no re-upload needed.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class ResumeContext {
  final String text;
  final String detectedRole;
  final String source; // 'ats' | 'analysis' | 'upload' | 'none'

  const ResumeContext({
    this.text = '',
    this.detectedRole = '',
    this.source = 'none',
  });

  bool get hasResume => text.trim().length > 80;

  ResumeContext copyWith({
    String? text,
    String? detectedRole,
    String? source,
  }) => ResumeContext(
    text: text ?? this.text,
    detectedRole: detectedRole ?? this.detectedRole,
    source: source ?? this.source,
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ResumeContextNotifier extends StateNotifier<ResumeContext> {
  ResumeContextNotifier() : super(const ResumeContext()) {
    _load();
  }

  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await _db.collection('resume_context').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final text = (data['resumeText'] as String?) ?? '';
        final role = (data['detectedRole'] as String?) ?? '';
        final source = (data['source'] as String?) ?? 'none';
        if (text.trim().length > 80) {
          state = ResumeContext(text: text, detectedRole: role, source: source);
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('resume_context').doc(uid).set({
        'resumeText': state.text,
        'detectedRole': state.detectedRole,
        'source': state.source,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> setResume(String extractedText, {required String source}) async {
    if (extractedText.trim().length < 50) return;
    final role = _detectJobRole(extractedText);
    state = ResumeContext(
      text: extractedText,
      detectedRole: role,
      source: source,
    );
    _save();
  }

  String _detectJobRole(String text) {
    final lower = text.toLowerCase();
    final roles = {
      'flutter developer': ['flutter', 'dart'],
      'android developer': ['android', 'kotlin'],
      'ios developer': ['swift', 'xcode'],
      'full stack developer': ['full stack', 'fullstack'],
      'frontend developer': ['react', 'vue', 'angular'],
      'backend developer': ['node.js', 'django', 'spring boot'],
      'data scientist': ['machine learning', 'data science', 'scikit'],
      'data analyst': ['sql', 'tableau', 'power bi'],
      'devops engineer': ['docker', 'kubernetes', 'ci/cd'],
      'cloud engineer': ['aws', 'azure', 'gcp'],
      'ml engineer': ['pytorch', 'keras', 'deep learning'],
      'software engineer': ['software engineer', 'software developer'],
    };
    for (final entry in roles.entries) {
      if (entry.value.any((k) => lower.contains(k))) return entry.key;
    }
    return 'software developer';
  }

  void clear() {
    state = const ResumeContext();
    final uid = _uid;
    if (uid != null) {
      _db.collection('resume_context').doc(uid).delete().catchError((_) {});
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final resumeContextProvider =
    StateNotifierProvider<ResumeContextNotifier, ResumeContext>(
      (_) => ResumeContextNotifier(),
    );
