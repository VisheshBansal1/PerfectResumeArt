// lib/providers/resume_context_provider.dart
//
// Single source of truth for the user's current resume.
// Persisted to Firestore (text only — PDF bytes are transient, in-memory only).
// PDF bytes are stored in memory while the app is open so Human Review
// can send the original PDF directly to the backend without Firebase Storage.

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class ResumeContext {
  final String text;
  final String detectedRole;
  final String source;

  // Transient — held in memory only, never written to Firestore or Storage.
  // Available as long as the app is open. Used by Human Review to attach
  // the original PDF to the admin email without needing Firebase Storage.
  final Uint8List? pdfBytes;
  final String fileName;

  const ResumeContext({
    this.text = '',
    this.detectedRole = '',
    this.source = 'none',
    this.pdfBytes,
    this.fileName = '',
  });

  bool get hasResume => text.trim().length > 80;
  bool get hasPdf    => pdfBytes != null && pdfBytes!.isNotEmpty;

  ResumeContext copyWith({
    String?    text,
    String?    detectedRole,
    String?    source,
    Uint8List? pdfBytes,
    String?    fileName,
  }) => ResumeContext(
    text:         text         ?? this.text,
    detectedRole: detectedRole ?? this.detectedRole,
    source:       source       ?? this.source,
    pdfBytes:     pdfBytes     ?? this.pdfBytes,
    fileName:     fileName     ?? this.fileName,
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ResumeContextNotifier extends StateNotifier<ResumeContext> {
  ResumeContextNotifier() : super(const ResumeContext()) {
    _load();
  }

  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Persistence (text only) ──────────────────────────────────────────────────

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await _db.collection('resume_context').doc(uid).get();
      if (doc.exists) {
        final data     = doc.data()!;
        final text     = (data['resumeText']   as String?) ?? '';
        final role     = (data['detectedRole'] as String?) ?? '';
        final source   = (data['source']       as String?) ?? 'none';
        final fileName = (data['fileName']     as String?) ?? '';
        if (text.trim().length > 80) {
          // pdfBytes not restored — user must re-upload PDF if they want to
          // submit Human Review after closing the app
          state = ResumeContext(
            text: text,
            detectedRole: role,
            source: source,
            fileName: fileName,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('resume_context').doc(uid).set({
        'resumeText':   state.text,
        'detectedRole': state.detectedRole,
        'source':       state.source,
        'fileName':     state.fileName,
        'updatedAt':    FieldValue.serverTimestamp(),
        // pdfBytes intentionally NOT saved — too large, not needed in Firestore
      });
    } catch (_) {}
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Use when you only have extracted text (no PDF — e.g. from ATS screen).
  Future<void> setResume(String extractedText, {required String source}) async {
    if (extractedText.trim().length < 50) return;
    state = state.copyWith(
      text:         extractedText,
      detectedRole: _detectJobRole(extractedText),
      source:       source,
    );
    await _save();
  }

  /// Use when you have BOTH text AND the original PDF bytes (from file picker).
  /// Stores bytes in memory so Human Review can attach them to the admin email.
  /// No Firebase Storage — bytes live in RAM, cleared when app closes.
  Future<void> setResumeWithPdf(
    String extractedText, {
    required String source,
    required Uint8List pdfBytes,
    required String originalFileName,
  }) async {
    if (extractedText.trim().length < 50) return;
    state = ResumeContext(
      text:         extractedText,
      detectedRole: _detectJobRole(extractedText),
      source:       source,
      pdfBytes:     pdfBytes,
      fileName:     originalFileName,
    );
    await _save();
  }

  void clear() {
    state = const ResumeContext();
    final uid = _uid;
    if (uid != null) {
      _db.collection('resume_context').doc(uid).delete().catchError((_) {});
    }
  }

  // ── Role detection ────────────────────────────────────────────────────────────

  String _detectJobRole(String text) {
    final lower = text.toLowerCase();
    final roles = {
      'flutter developer':    ['flutter', 'dart'],
      'android developer':    ['android', 'kotlin'],
      'ios developer':        ['swift', 'xcode'],
      'full stack developer': ['full stack', 'fullstack'],
      'frontend developer':   ['react', 'vue', 'angular'],
      'backend developer':    ['node.js', 'django', 'spring boot'],
      'data scientist':       ['machine learning', 'data science', 'scikit'],
      'data analyst':         ['sql', 'tableau', 'power bi'],
      'devops engineer':      ['docker', 'kubernetes', 'ci/cd'],
      'cloud engineer':       ['aws', 'azure', 'gcp'],
      'ml engineer':          ['pytorch', 'keras', 'deep learning'],
      'software engineer':    ['software engineer', 'software developer'],
    };
    for (final entry in roles.entries) {
      if (entry.value.any((k) => lower.contains(k))) return entry.key;
    }
    return 'software developer';
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final resumeContextProvider =
    StateNotifierProvider<ResumeContextNotifier, ResumeContext>(
      (_) => ResumeContextNotifier(),
    );
