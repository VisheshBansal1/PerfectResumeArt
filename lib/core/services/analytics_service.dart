import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Tracks user funnel events to Firestore.
///
/// Funnel stages:
///   upload_resume → view_premium_hub → view_plan → payment_started
///   → payment_success | payment_failed → tool_used
///
/// Query in Firebase console to find drop-off points.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;
  AnalyticsService._();

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Low-level event logger. All public methods call this.
  Future<void> _log(String event, [Map<String, dynamic>? props]) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('analytics_events').add({
        'uid': uid,
        'event': event,
        'ts': FieldValue.serverTimestamp(),
        ...?props,
      });
      // Also update the user's funnel doc for easy aggregation
      await _db.collection('analytics_funnel').doc(uid).set({
        'lastEvent': event,
        'lastSeen': FieldValue.serverTimestamp(),
        event: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Analytics] log error: $e');
    }
  }

  // ── Funnel events ─────────────────────────────────────────────────────────

  Future<void> resumeUploaded() => _log('upload_resume');

  Future<void> premiumHubViewed() => _log('view_premium_hub');

  Future<void> planViewed(String planKey) =>
      _log('view_plan', {'plan': planKey});

  Future<void> paymentStarted(String planKey) =>
      _log('payment_started', {'plan': planKey});

  Future<void> paymentSuccess(String planKey, String paymentId) =>
      _log('payment_success', {'plan': planKey, 'paymentId': paymentId});

  Future<void> paymentFailed(String planKey, String? error) =>
      _log('payment_failed', {'plan': planKey, 'error': error});

  Future<void> toolUsed(String toolName) =>
      _log('tool_used', {'tool': toolName});

  Future<void> pdfDownloaded(String toolName) =>
      _log('pdf_downloaded', {'tool': toolName});

  Future<void> shareCardShown(String toolName) =>
      _log('share_card_shown', {'tool': toolName});

  Future<void> humanReviewSubmitted() => _log('human_review_submitted');

  // ── Aggregate helpers (for admin dashboard) ────────────────────────────────

  /// Returns conversion rate between two funnel stages.
  /// Useful to show in admin analytics screen.
  Future<Map<String, int>> getFunnelCounts() async {
    final stages = [
      'upload_resume',
      'view_premium_hub',
      'view_plan',
      'payment_started',
      'payment_success',
    ];
    final result = <String, int>{};
    try {
      for (final stage in stages) {
        final snap = await _db
            .collection('analytics_funnel')
            .where(stage, isGreaterThan: 0)
            .count()
            .get();
        result[stage] = snap.count ?? 0;
      }
    } catch (e) {
      debugPrint('[Analytics] getFunnelCounts error: $e');
    }
    return result;
  }
}
