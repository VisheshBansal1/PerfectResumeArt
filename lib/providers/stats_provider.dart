// lib/providers/stats_provider.dart
//
// Add this file at: lib/providers/stats_provider.dart
//
// Provides a FutureProvider that reads the total count of all analyses across
// all users from Firestore. Used by HomeScreen to show the social-proof counter
// "127+ Resumes Analyzed".
//
// HOW TO INCREMENT (backend side):
//   Every time saveAnalysis() is called in firebase_service.dart, also call:
//     _incrementAnalysisCount();
//   That method is defined below as a FirebaseService extension.
//
// Firestore document path: /stats/global
//   { "totalAnalyses": 127 }
//
// You can seed this manually in the Firebase Console or wait for real usage.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads the total analyses count from Firestore.
/// Returns 0 if the document doesn't exist yet.
final totalAnalysesCountProvider = FutureProvider<int>((ref) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('stats')
        .doc('global')
        .get();

    if (!doc.exists) return 0;
    return (doc.data()?['totalAnalyses'] as int?) ?? 0;
  } catch (_) {
    return 0;
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// HOW TO CALL THIS FROM firebase_service.dart
// ─────────────────────────────────────────────────────────────────────────────
//
// In your existing FirebaseService.saveAnalysis() method, add one line:
//
//   Future<String> saveAnalysis(AnalysisModel analysis) async {
//     final docRef = await _db
//         .collection(AppConstants.analysisCollection)
//         .add(analysis.toMap());
//
//     // ← ADD THIS LINE
//     unawaited(_incrementAnalysisCount());
//
//     return docRef.id;
//   }
//
//   // ← ADD THIS METHOD
//   Future<void> _incrementAnalysisCount() async {
//     try {
//       await _db.collection('stats').doc('global').set(
//         {'totalAnalyses': FieldValue.increment(1)},
//         SetOptions(merge: true),
//       );
//     } catch (_) {
//       // Non-critical — don't crash the analysis save if this fails
//     }
//   }
//
// The 'unawaited' call means the counter update happens in the background
// without blocking the user from seeing their results.
// Import it with: import 'dart:async' show unawaited;