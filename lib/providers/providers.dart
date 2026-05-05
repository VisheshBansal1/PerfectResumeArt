import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/services/firebase_service.dart';
import '../core/services/ocr_service.dart';
import '../core/services/ai_service.dart';
import '../models/models.dart';
import '../features/auth/providers/auth_provider.dart';

// ─── Service Providers ────────────────────────────────────────
final ocrServiceProvider = Provider<OcrService>((ref) => OcrService());
final aiServiceProvider = Provider<AiService>((ref) => AiService());

// ─── Jobs Providers ───────────────────────────────────────────
final jobsProvider = StreamProvider<List<JobModel>>((ref) {
  final service = ref.watch(firebaseServiceProvider);
  return service.watchJobs();
});

final activeJobsProvider = FutureProvider<List<JobModel>>((ref) async {
  final service = ref.read(firebaseServiceProvider);
  return service.getActiveJobs();
});

final allJobsProvider = FutureProvider<List<JobModel>>((ref) async {
  final service = ref.read(firebaseServiceProvider);
  return service.getAllJobs();
});

/// Fetch a single job by its Firestore document ID.
final jobByIdProvider = FutureProvider.family<JobModel?, String>((
  ref,
  jobId,
) async {
  final service = ref.read(firebaseServiceProvider);
  return service.getJob(jobId);
});

// ─── Recruiter-scoped Providers ───────────────────────────────

/// All jobs created by the currently signed-in recruiter.
final recruiterJobsProvider = Provider<AsyncValue<List<JobModel>>>((ref) {
  final uid = ref
      .watch(currentUserProvider)
      .maybeWhen(data: (u) => u?.uid, orElse: () => null);
  final allJobs = ref.watch(jobsProvider);
  if (uid == null) return const AsyncData([]);
  return allJobs.when(
    data: (jobs) => AsyncData(jobs.where((j) => j.createdBy == uid).toList()),
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});

/// All analyses that belong to the current recruiter's jobs only.
final recruiterAnalysesProvider = Provider<AsyncValue<List<AnalysisModel>>>((
  ref,
) {
  final recruiterJobs = ref.watch(recruiterJobsProvider);
  final allAnalyses = ref.watch(allAnalysesProvider);

  final jobIds = recruiterJobs.maybeWhen(
    data: (jobs) => jobs.map((j) => j.id).toSet(),
    orElse: () => <String>{},
  );

  return allAnalyses.when(
    data: (list) =>
        AsyncData(list.where((a) => jobIds.contains(a.jobId)).toList()),
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});

/// Analytics computed from the recruiter's own data only.
final recruiterAnalyticsProvider = Provider<AsyncValue<Map<String, dynamic>>>((
  ref,
) {
  final recruiterJobs = ref.watch(recruiterJobsProvider);
  final recruiterAnalyses = ref.watch(recruiterAnalysesProvider);

  return recruiterAnalyses.when(
    data: (list) {
      final jobs = recruiterJobs.maybeWhen(
        data: (j) => j,
        orElse: () => <JobModel>[],
      );
      return AsyncData(_computeAnalytics(list, jobs));
    },
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});

Map<String, dynamic> _computeAnalytics(
  List<AnalysisModel> analyses,
  List<JobModel> jobs,
) {
  final total = analyses.length;
  final avgScore = total == 0
      ? 0
      : (analyses.map((a) => a.overallScore).reduce((a, b) => a + b) / total)
            .round();

  final scoreRanges = {
    '0-40': analyses.where((a) => a.overallScore < 40).length,
    '40-60': analyses
        .where((a) => a.overallScore >= 40 && a.overallScore < 60)
        .length,
    '60-80': analyses
        .where((a) => a.overallScore >= 60 && a.overallScore < 80)
        .length,
    '80-100': analyses.where((a) => a.overallScore >= 80).length,
  };

  final jobStats = <String, Map<String, dynamic>>{};
  for (final analysis in analyses) {
    if (analysis.jobId == 'ats_check' || analysis.jobId == 'custom') continue;
    jobStats.putIfAbsent(
      analysis.jobTitle,
      () => {
        'count': 0,
        'totalScore': 0,
        'pass': 0,
        'fail': 0,
        'highPotential': 0,
      },
    );
    jobStats[analysis.jobTitle]!['count'] =
        (jobStats[analysis.jobTitle]!['count'] as int) + 1;
    jobStats[analysis.jobTitle]!['totalScore'] =
        (jobStats[analysis.jobTitle]!['totalScore'] as int) +
        analysis.overallScore;
    if (analysis.adminDecision == 'Pass') {
      jobStats[analysis.jobTitle]!['pass'] =
          (jobStats[analysis.jobTitle]!['pass'] as int) + 1;
    } else if (analysis.adminDecision == 'Fail') {
      jobStats[analysis.jobTitle]!['fail'] =
          (jobStats[analysis.jobTitle]!['fail'] as int) + 1;
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
      'custom_tech': analyses
          .where((a) => a.analysisType == 'custom_tech')
          .length,
    },
    'decisions': {
      'pass': analyses.where((a) => a.adminDecision == 'Pass').length,
      'fail': analyses.where((a) => a.adminDecision == 'Fail').length,
      'highPotential': analyses
          .where((a) => a.adminDecision == 'High Potential')
          .length,
      'pending': analyses.where((a) => a.adminDecision == null).length,
    },
  };
}

// ─── Resume Upload State ───────────────────────────────────────
class ResumeUploadState {
  final bool isExtracting;
  final bool isAnalyzing;
  final String? error;
  final String? extractedText;
  final String? uploadedResumeId;
  final String? analysisId;

  const ResumeUploadState({
    this.isExtracting = false,
    this.isAnalyzing = false,
    this.error,
    this.extractedText,
    this.uploadedResumeId,
    this.analysisId,
  });

  bool get isLoading => isExtracting || isAnalyzing;
  bool get isUploading => isLoading;

  ResumeUploadState copyWith({
    bool? isExtracting,
    bool? isAnalyzing,
    Object? error = _kKeepValue,
    String? extractedText,
    String? uploadedResumeId,
    String? analysisId,
  }) => ResumeUploadState(
    isExtracting: isExtracting ?? this.isExtracting,
    isAnalyzing: isAnalyzing ?? this.isAnalyzing,
    error: error == _kKeepValue ? this.error : error as String?,
    extractedText: extractedText ?? this.extractedText,
    uploadedResumeId: uploadedResumeId ?? this.uploadedResumeId,
    analysisId: analysisId ?? this.analysisId,
  );
}

const _kKeepValue = Object();

final resumeUploadProvider =
    StateNotifierProvider<ResumeUploadNotifier, ResumeUploadState>((ref) {
      return ResumeUploadNotifier(
        ref.read(firebaseServiceProvider),
        ref.read(ocrServiceProvider),
        ref.read(aiServiceProvider),
      );
    });

class ResumeUploadNotifier extends StateNotifier<ResumeUploadState> {
  final FirebaseService _firebaseService;
  final OcrService _ocrService;
  final AiService _aiService;

  ResumeUploadNotifier(this._firebaseService, this._ocrService, this._aiService)
    : super(const ResumeUploadState());

  Future<void> extractText(File file) async {
    state = state.copyWith(isExtracting: true, error: null);
    try {
      final result = await _ocrService.extractText(file);
      state = state.copyWith(isExtracting: false, extractedText: result.text);
    } catch (e) {
      state = state.copyWith(isExtracting: false, error: e.toString());
    }
  }

  Future<String?> uploadAndAnalyze({
    required File file,
    required JobModel selectedJob,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      state = state.copyWith(isExtracting: true, error: null);
      final extension = file.path.split('.').last.toLowerCase();
      final ocrResult = await _ocrService.extractText(file);
      state = state.copyWith(
        isExtracting: false,
        extractedText: ocrResult.text,
      );
      final resume = await _firebaseService.saveResumeMetadata(
        userId: uid,
        fileName: path.basename(file.path),
        fileType: extension == 'pdf' ? 'pdf' : 'image',
        extractedText: ocrResult.text,
      );
      state = state.copyWith(uploadedResumeId: resume.id);
      state = state.copyWith(isAnalyzing: true);
      final analysis = await _aiService.analyzeResume(
        resumeText: ocrResult.text,
        job: selectedJob,
        userId: uid,
        resumeId: resume.id,
        analysisType: 'full',
      );
      final analysisId = await _firebaseService.saveAnalysis(analysis);
      state = state.copyWith(isAnalyzing: false, analysisId: analysisId);
      return analysisId;
    } catch (e) {
      state = state.copyWith(
        isExtracting: false,
        isAnalyzing: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<String?> uploadAndAnalyzeCustom({
    required File file,
    required String jobTitle,
    required List<String> requiredSkills,
    required String description,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      state = state.copyWith(isExtracting: true, error: null);
      final extension = file.path.split('.').last.toLowerCase();
      final ocrResult = await _ocrService.extractText(file);
      state = state.copyWith(
        isExtracting: false,
        extractedText: ocrResult.text,
      );
      final resume = await _firebaseService.saveResumeMetadata(
        userId: uid,
        fileName: path.basename(file.path),
        fileType: extension == 'pdf' ? 'pdf' : 'image',
        extractedText: ocrResult.text,
      );
      state = state.copyWith(uploadedResumeId: resume.id);
      state = state.copyWith(isAnalyzing: true);
      final analysis = await _aiService.analyzeWithCustomTech(
        resumeText: ocrResult.text,
        jobTitle: jobTitle,
        requiredSkills: requiredSkills,
        description: description,
        userId: uid,
        resumeId: resume.id,
      );
      final analysisId = await _firebaseService.saveAnalysis(analysis);
      state = state.copyWith(isAnalyzing: false, analysisId: analysisId);
      return analysisId;
    } catch (e) {
      state = state.copyWith(
        isExtracting: false,
        isAnalyzing: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<String?> uploadAndAnalyzeAts({required File file}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      state = state.copyWith(isExtracting: true, error: null);
      final extension = file.path.split('.').last.toLowerCase();
      final ocrResult = await _ocrService.extractText(file);
      state = state.copyWith(
        isExtracting: false,
        extractedText: ocrResult.text,
      );
      final resume = await _firebaseService.saveResumeMetadata(
        userId: uid,
        fileName: path.basename(file.path),
        fileType: extension == 'pdf' ? 'pdf' : 'image',
        extractedText: ocrResult.text,
      );
      state = state.copyWith(uploadedResumeId: resume.id);
      state = state.copyWith(isAnalyzing: true);
      final analysis = await _aiService.analyzeAtsOnly(
        resumeText: ocrResult.text,
        userId: uid,
        resumeId: resume.id,
      );
      final analysisId = await _firebaseService.saveAnalysis(analysis);
      state = state.copyWith(isAnalyzing: false, analysisId: analysisId);
      return analysisId;
    } catch (e) {
      state = state.copyWith(
        isExtracting: false,
        isAnalyzing: false,
        error: e.toString(),
      );
      return null;
    }
  }

  // ── Web-safe bytes-based variants ────────────────────────────────────────

  Future<void> extractTextFromBytes({
    required Uint8List bytes,
    required String extension,
  }) async {
    state = state.copyWith(isExtracting: true, error: null);
    try {
      final result = await _ocrService.extractTextFromBytes(
        bytes: bytes,
        extension: extension,
      );
      state = state.copyWith(isExtracting: false, extractedText: result.text);
    } catch (e) {
      state = state.copyWith(isExtracting: false, error: e.toString());
    }
  }

  Future<String?> uploadAndAnalyzeFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String extension,
    required JobModel selectedJob,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      state = state.copyWith(isExtracting: true, error: null);
      final ocrResult = await _ocrService.extractTextFromBytes(
        bytes: bytes,
        extension: extension,
      );
      state = state.copyWith(
        isExtracting: false,
        extractedText: ocrResult.text,
      );
      final resume = await _firebaseService.saveResumeMetadata(
        userId: uid,
        fileName: fileName,
        fileType: extension == 'pdf' ? 'pdf' : 'image',
        extractedText: ocrResult.text,
      );
      state = state.copyWith(uploadedResumeId: resume.id, isAnalyzing: true);
      final analysis = await _aiService.analyzeResume(
        resumeText: ocrResult.text,
        job: selectedJob,
        userId: uid,
        resumeId: resume.id,
        analysisType: 'full',
      );
      final analysisId = await _firebaseService.saveAnalysis(analysis);
      state = state.copyWith(isAnalyzing: false, analysisId: analysisId);
      return analysisId;
    } catch (e) {
      state = state.copyWith(
        isExtracting: false,
        isAnalyzing: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<String?> uploadAndAnalyzeAtsFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String extension,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      state = state.copyWith(isExtracting: true, error: null);
      final ocrResult = await _ocrService.extractTextFromBytes(
        bytes: bytes,
        extension: extension,
      );
      state = state.copyWith(
        isExtracting: false,
        extractedText: ocrResult.text,
      );
      final resume = await _firebaseService.saveResumeMetadata(
        userId: uid,
        fileName: fileName,
        fileType: extension == 'pdf' ? 'pdf' : 'image',
        extractedText: ocrResult.text,
      );
      state = state.copyWith(uploadedResumeId: resume.id, isAnalyzing: true);
      final analysis = await _aiService.analyzeAtsOnly(
        resumeText: ocrResult.text,
        userId: uid,
        resumeId: resume.id,
      );
      final analysisId = await _firebaseService.saveAnalysis(analysis);
      state = state.copyWith(isAnalyzing: false, analysisId: analysisId);
      return analysisId;
    } catch (e) {
      state = state.copyWith(
        isExtracting: false,
        isAnalyzing: false,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<String?> uploadAndAnalyzeCustomFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String extension,
    required String jobTitle,
    required List<String> requiredSkills,
    required String description,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      state = state.copyWith(isExtracting: true, error: null);
      final ocrResult = await _ocrService.extractTextFromBytes(
        bytes: bytes,
        extension: extension,
      );
      state = state.copyWith(
        isExtracting: false,
        extractedText: ocrResult.text,
      );
      final resume = await _firebaseService.saveResumeMetadata(
        userId: uid,
        fileName: fileName,
        fileType: extension == 'pdf' ? 'pdf' : 'image',
        extractedText: ocrResult.text,
      );
      state = state.copyWith(uploadedResumeId: resume.id, isAnalyzing: true);
      final analysis = await _aiService.analyzeWithCustomTech(
        resumeText: ocrResult.text,
        jobTitle: jobTitle,
        requiredSkills: requiredSkills,
        description: description,
        userId: uid,
        resumeId: resume.id,
      );
      final analysisId = await _firebaseService.saveAnalysis(analysis);
      state = state.copyWith(isAnalyzing: false, analysisId: analysisId);
      return analysisId;
    } catch (e) {
      state = state.copyWith(
        isExtracting: false,
        isAnalyzing: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void reset() => state = const ResumeUploadState();
  void clearError() => state = state.copyWith(error: null);
}

// ─── Analysis Providers ───────────────────────────────────────
final analysisProvider = FutureProvider.family<AnalysisModel?, String>((
  ref,
  id,
) async {
  final service = ref.read(firebaseServiceProvider);
  return service.getAnalysis(id);
});

/// Fetches a single ResumeModel by its Firestore document ID.
final resumeByIdProvider = FutureProvider.family<ResumeModel?, String>((
  ref,
  id,
) async {
  if (id.isEmpty) return null;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final service = ref.read(firebaseServiceProvider);
  final resumes = await service.getUserResumes(uid);
  try {
    return resumes.firstWhere((r) => r.id == id);
  } catch (_) {
    return null;
  }
});

final userAnalysesProvider = FutureProvider<List<AnalysisModel>>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return [];
  final service = ref.read(firebaseServiceProvider);
  return service.getUserAnalyses(uid);
});

final allAnalysesProvider = StreamProvider<List<AnalysisModel>>((ref) {
  final service = ref.read(firebaseServiceProvider);
  return service.watchAllAnalyses();
});

final analysesByJobProvider =
    StreamProvider.family<List<AnalysisModel>, String>((ref, jobId) {
      final service = ref.read(firebaseServiceProvider);
      return service.watchAnalysesByJob(jobId);
    });

// ─── Admin Analytics Provider (legacy) ───────────────────────
final adminAnalyticsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final service = ref.read(firebaseServiceProvider);
  return service.getAnalyticsData();
});

// ─── Admin Decision Provider ──────────────────────────────────
final adminDecisionProvider =
    StateNotifierProvider<AdminDecisionNotifier, AsyncValue<void>>((ref) {
      return AdminDecisionNotifier(ref.read(firebaseServiceProvider));
    });

class AdminDecisionNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseService _service;
  AdminDecisionNotifier(this._service) : super(const AsyncData(null));

  Future<void> makeDecision({
    required String analysisId,
    required String decision,
    required String notes,
  }) async {
    state = const AsyncLoading();
    try {
      await _service.updateAdminDecision(
        analysisId: analysisId,
        decision: decision,
        notes: notes,
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ─── Job Management Provider ──────────────────────────────────
final jobManagementProvider =
    StateNotifierProvider<JobManagementNotifier, AsyncValue<void>>((ref) {
      return JobManagementNotifier(ref.read(firebaseServiceProvider));
    });

class JobManagementNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseService _service;
  JobManagementNotifier(this._service) : super(const AsyncData(null));

  Future<String?> createJob(JobModel job) async {
    state = const AsyncLoading();
    try {
      final id = await _service.createJob(job);
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> toggleJob(String jobId, bool isActive) async {
    await _service.updateJob(jobId, {'isActive': isActive});
  }

  Future<void> updateJob(String jobId, JobModel job) async {
    await _service.updateFullJob(jobId, job);
  }
}
