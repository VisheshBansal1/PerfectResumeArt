import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../constants/app_constants.dart';

/// FirebaseService — uses Firestore only (no Firebase Storage).
/// Resume files are processed in-memory (OCR/extract) and only the
/// extracted text + metadata are saved. This avoids the paid
/// Firebase Storage tier entirely.
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  // ─── User Operations ─────────────────────────────────────────
  Future<void> createUser(UserModel user) async {
    await _db.collection(AppConstants.usersCollection).doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, uid);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update(data);
  }

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'user')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
  }

  Future<int> getUserCount() async {
    final snapshot = await _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'user')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ─── Job Operations ──────────────────────────────────────────
  Future<String> createJob(JobModel job) async {
    final docRef = await _db.collection(AppConstants.jobsCollection).add(job.toMap());
    return docRef.id;
  }

  Future<List<JobModel>> getActiveJobs() async {
    final snapshot = await _db
        .collection(AppConstants.jobsCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((d) => JobModel.fromMap(d.data(), d.id)).toList();
  }

  Future<List<JobModel>> getAllJobs() async {
    final snapshot = await _db
        .collection(AppConstants.jobsCollection)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((d) => JobModel.fromMap(d.data(), d.id)).toList();
  }

  Future<JobModel?> getJob(String jobId) async {
    final doc = await _db.collection(AppConstants.jobsCollection).doc(jobId).get();
    if (!doc.exists) return null;
    return JobModel.fromMap(doc.data()!, jobId);
  }

  Stream<List<JobModel>> watchJobs() {
    return _db
        .collection(AppConstants.jobsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => JobModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> updateJob(String jobId, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.jobsCollection).doc(jobId).update(data);
  }

  Future<void> deleteJob(String jobId) async {
    await _db
        .collection(AppConstants.jobsCollection)
        .doc(jobId)
        .update({'isActive': false});
  }

  Future<void> updateFullJob(String jobId, JobModel job) async {
    await _db.collection(AppConstants.jobsCollection).doc(jobId).update(job.toMap());
  }

  // ─── Resume Operations (No Storage — Firestore only) ─────────
  /// Saves resume metadata + extracted text to Firestore.
  /// The actual file is NOT uploaded anywhere — it was already
  /// processed locally by OcrService. This is free-tier friendly.
  Future<ResumeModel> saveResumeMetadata({
    required String userId,
    required String fileName,
    required String fileType,
    required String extractedText,
  }) async {
    final id = _uuid.v4();

    final resume = ResumeModel(
      id: id,
      userId: userId,
      fileName: fileName,
      fileUrl: null, // No storage — file stays local
      fileType: fileType,
      extractedText: extractedText,
      uploadedAt: DateTime.now(),
    );

    await _db.collection(AppConstants.resumesCollection).doc(id).set(resume.toMap());
    return resume;
  }

  Future<List<ResumeModel>> getUserResumes(String userId) async {
    final snapshot = await _db
        .collection(AppConstants.resumesCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snapshot.docs.map((d) => ResumeModel.fromMap(d.data(), d.id)).toList();
  }

  // ─── Analysis Operations ──────────────────────────────────────
  Future<String> saveAnalysis(AnalysisModel analysis) async {
    final docRef = await _db
        .collection(AppConstants.analysisCollection)
        .add(analysis.toMap());
    return docRef.id;
  }

  Future<AnalysisModel?> getAnalysis(String analysisId) async {
    final doc = await _db
        .collection(AppConstants.analysisCollection)
        .doc(analysisId)
        .get();
    if (!doc.exists) return null;
    return AnalysisModel.fromMap(doc.data()!, analysisId);
  }

  Future<List<AnalysisModel>> getUserAnalyses(String userId) async {
    final snapshot = await _db
        .collection(AppConstants.analysisCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('analyzedAt', descending: true)
        .get();
    return snapshot.docs.map((d) => AnalysisModel.fromMap(d.data(), d.id)).toList();
  }

  Stream<List<AnalysisModel>> watchAllAnalyses() {
    return _db
        .collection(AppConstants.analysisCollection)
        .orderBy('analyzedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AnalysisModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<AnalysisModel>> watchAnalysesByJob(String jobId) {
    return _db
        .collection(AppConstants.analysisCollection)
        .where('jobId', isEqualTo: jobId)
        .orderBy('overallScore', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AnalysisModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> updateAdminDecision({
    required String analysisId,
    required String decision,
    required String notes,
  }) async {
    await _db.collection(AppConstants.analysisCollection).doc(analysisId).update({
      'adminDecision': decision,
      'adminNotes': notes,
      'decidedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Analytics Helpers ────────────────────────────────────────
  Future<Map<String, dynamic>> getAnalyticsData() async {
    final snapshot = await _db.collection(AppConstants.analysisCollection).get();
    final analyses = snapshot.docs.map((d) => AnalysisModel.fromMap(d.data(), d.id)).toList();

    final total = analyses.length;
    final avgScore = total == 0
        ? 0
        : (analyses.map((a) => a.overallScore).reduce((a, b) => a + b) / total).round();

    final scoreRanges = {
      '0-40': analyses.where((a) => a.overallScore < 40).length,
      '40-60': analyses.where((a) => a.overallScore >= 40 && a.overallScore < 60).length,
      '60-80': analyses.where((a) => a.overallScore >= 60 && a.overallScore < 80).length,
      '80-100': analyses.where((a) => a.overallScore >= 80).length,
    };

    final jobStats = <String, Map<String, dynamic>>{};
    for (final analysis in analyses) {
      if (analysis.jobId == 'ats_check' || analysis.jobId == 'custom') continue;
      jobStats.putIfAbsent(analysis.jobTitle, () => {
        'count': 0,
        'totalScore': 0,
        'pass': 0,
        'fail': 0,
        'highPotential': 0,
      });
      jobStats[analysis.jobTitle]!['count'] = (jobStats[analysis.jobTitle]!['count'] as int) + 1;
      jobStats[analysis.jobTitle]!['totalScore'] =
          (jobStats[analysis.jobTitle]!['totalScore'] as int) + analysis.overallScore;
      if (analysis.adminDecision == 'Pass') {
        jobStats[analysis.jobTitle]!['pass'] = (jobStats[analysis.jobTitle]!['pass'] as int) + 1;
      } else if (analysis.adminDecision == 'Fail') {
        jobStats[analysis.jobTitle]!['fail'] = (jobStats[analysis.jobTitle]!['fail'] as int) + 1;
      } else if (analysis.adminDecision == 'High Potential') {
        jobStats[analysis.jobTitle]!['highPotential'] =
            (jobStats[analysis.jobTitle]!['highPotential'] as int) + 1;
      }
    }

    return {
      'total': total,
      'avgScore': avgScore,
      'scoreRanges': scoreRanges,
      'jobStats': jobStats,
      'byType': {
        'full': analyses.where((a) => a.analysisType == 'full').length,
        'ats_only': analyses.where((a) => a.analysisType == 'ats_only').length,
        'custom_tech': analyses.where((a) => a.analysisType == 'custom_tech').length,
      },
      'decisions': {
        'pass': analyses.where((a) => a.adminDecision == 'Pass').length,
        'fail': analyses.where((a) => a.adminDecision == 'Fail').length,
        'highPotential': analyses.where((a) => a.adminDecision == 'High Potential').length,
        'pending': analyses.where((a) => a.adminDecision == null).length,
      },
    };
  }
}