import 'package:cloud_firestore/cloud_firestore.dart';

// ─── User Model ───────────────────────────────────────────────────────────────
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'user' | 'admin'
  final String? photoUrl;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) => UserModel(
    uid: uid,
    email: map['email'] as String? ?? '',
    name: map['name'] as String? ?? '',
    role: map['role'] as String? ?? 'user',
    photoUrl: map['photoUrl'] as String?,
    // FIX: handle both Firestore Timestamp AND plain DateTime
    // (Google sign-in can store DateTime directly; email sign-in stores Timestamp)
    createdAt: _toDateTime(map['createdAt']),
  );

  static DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    // Fallback — shouldn't happen but prevents a crash
    return DateTime.now();
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'role': role,
    'photoUrl': photoUrl,
    // FIX: always store as Firestore Timestamp (not raw DateTime)
    // so reads are always consistent
    'createdAt': Timestamp.fromDate(createdAt),
  };

  UserModel copyWith({String? name, String? role, String? photoUrl}) =>
      UserModel(
        uid: uid,
        email: email,
        name: name ?? this.name,
        role: role ?? this.role,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt,
      );
}

// ─── Job Model ────────────────────────────────────────────────────────────────
class JobModel {
  final String id;
  final String title;
  final String description;
  final List<String> requiredSkills;
  final List<String> preferredSkills;
  final int minExperience;
  final List<String> requiredProjectTypes;
  final String createdBy;
  final DateTime createdAt;
  final bool isActive;

  const JobModel({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredSkills,
    required this.preferredSkills,
    required this.minExperience,
    required this.requiredProjectTypes,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
  });

  factory JobModel.fromMap(Map<String, dynamic> map, String id) => JobModel(
    id: id,
    title: map['title'] as String? ?? '',
    description: map['description'] as String? ?? '',
    requiredSkills: List<String>.from(map['requiredSkills'] ?? []),
    preferredSkills: List<String>.from(map['preferredSkills'] ?? []),
    minExperience: map['minExperience'] as int? ?? 0,
    requiredProjectTypes: List<String>.from(map['requiredProjectTypes'] ?? []),
    createdBy: map['createdBy'] as String? ?? '',
    createdAt: _toDateTime(map['createdAt']),
    isActive: map['isActive'] as bool? ?? true,
  );

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'requiredSkills': requiredSkills,
    'preferredSkills': preferredSkills,
    'minExperience': minExperience,
    'requiredProjectTypes': requiredProjectTypes,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'isActive': isActive,
  };
}

// ─── Resume Model ─────────────────────────────────────────────────────────────
class ResumeModel {
  final String id;
  final String userId;
  final String fileName;
  final String? fileUrl;
  final String fileType;
  final String extractedText;
  final DateTime uploadedAt;

  const ResumeModel({
    required this.id,
    required this.userId,
    required this.fileName,
    this.fileUrl,
    required this.fileType,
    required this.extractedText,
    required this.uploadedAt,
  });

  factory ResumeModel.fromMap(Map<String, dynamic> map, String id) =>
      ResumeModel(
        id: id,
        userId: map['userId'] as String? ?? '',
        fileName: map['fileName'] as String? ?? '',
        fileUrl: map['fileUrl'] as String?,
        fileType: map['fileType'] as String? ?? 'pdf',
        extractedText: map['extractedText'] as String? ?? '',
        uploadedAt: _toDateTime(map['uploadedAt']),
      );

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'fileName': fileName,
    'fileUrl': fileUrl,
    'fileType': fileType,
    'extractedText': extractedText,
    'uploadedAt': Timestamp.fromDate(uploadedAt),
  };
}

// ─── Analysis Models ──────────────────────────────────────────────────────────
class ProjectAnalysis {
  final String name;
  final int score;
  final List<String> issues;
  final List<String> suggestions;
  final String techStack;
  final String complexity;

  const ProjectAnalysis({
    required this.name,
    required this.score,
    required this.issues,
    required this.suggestions,
    required this.techStack,
    required this.complexity,
  });

  factory ProjectAnalysis.fromMap(Map<String, dynamic> map) => ProjectAnalysis(
    name: map['name'] as String? ?? '',
    score: map['score'] as int? ?? 0,
    issues: List<String>.from(map['issues'] ?? []),
    suggestions: List<String>.from(map['suggestions'] ?? []),
    techStack: map['techStack'] as String? ?? '',
    complexity: map['complexity'] as String? ?? 'Medium',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'score': score,
    'issues': issues,
    'suggestions': suggestions,
    'techStack': techStack,
    'complexity': complexity,
  };
}

class AnalysisModel {
  final String id;
  final String userId;
  final String resumeId;
  final String jobId;
  final String jobTitle;
  final String analysisType;
  final int matchScore;
  final int atsScore;
  final int projectScore;
  final int overallScore;
  final List<String> missingSkills;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<ProjectAnalysis> projects;
  final String finalRecommendation;
  final List<String> suggestions;
  final DateTime analyzedAt;
  final String? adminDecision;
  final String? adminNotes;

  const AnalysisModel({
    required this.id,
    required this.userId,
    required this.resumeId,
    required this.jobId,
    required this.jobTitle,
    this.analysisType = 'full',
    required this.matchScore,
    required this.atsScore,
    required this.projectScore,
    required this.overallScore,
    required this.missingSkills,
    required this.strengths,
    required this.weaknesses,
    required this.projects,
    required this.finalRecommendation,
    required this.suggestions,
    required this.analyzedAt,
    this.adminDecision,
    this.adminNotes,
  });

  factory AnalysisModel.fromMap(Map<String, dynamic> map, String id) =>
      AnalysisModel(
        id: id,
        userId: map['userId'] as String? ?? '',
        resumeId: map['resumeId'] as String? ?? '',
        jobId: map['jobId'] as String? ?? '',
        jobTitle: map['jobTitle'] as String? ?? '',
        analysisType: map['analysisType'] as String? ?? 'full',
        matchScore: map['matchScore'] as int? ?? 0,
        atsScore: map['atsScore'] as int? ?? 0,
        projectScore: map['projectScore'] as int? ?? 0,
        overallScore: map['overallScore'] as int? ?? 0,
        missingSkills: List<String>.from(map['missingSkills'] ?? []),
        strengths: List<String>.from(map['strengths'] ?? []),
        weaknesses: List<String>.from(map['weaknesses'] ?? []),
        projects: (map['projects'] as List<dynamic>? ?? [])
            .map((p) => ProjectAnalysis.fromMap(p as Map<String, dynamic>))
            .toList(),
        finalRecommendation: map['finalRecommendation'] as String? ?? 'Fail',
        suggestions: List<String>.from(map['suggestions'] ?? []),
        analyzedAt: _toDateTime(map['analyzedAt']),
        adminDecision: map['adminDecision'] as String?,
        adminNotes: map['adminNotes'] as String?,
      );

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'resumeId': resumeId,
    'jobId': jobId,
    'jobTitle': jobTitle,
    'analysisType': analysisType,
    'matchScore': matchScore,
    'atsScore': atsScore,
    'projectScore': projectScore,
    'overallScore': overallScore,
    'missingSkills': missingSkills,
    'strengths': strengths,
    'weaknesses': weaknesses,
    'projects': projects.map((p) => p.toMap()).toList(),
    'finalRecommendation': finalRecommendation,
    'suggestions': suggestions,
    'analyzedAt': Timestamp.fromDate(analyzedAt),
    'adminDecision': adminDecision,
    'adminNotes': adminNotes,
  };

  AnalysisModel copyWith({String? adminDecision, String? adminNotes}) =>
      AnalysisModel(
        id: id,
        userId: userId,
        resumeId: resumeId,
        jobId: jobId,
        jobTitle: jobTitle,
        analysisType: analysisType,
        matchScore: matchScore,
        atsScore: atsScore,
        projectScore: projectScore,
        overallScore: overallScore,
        missingSkills: missingSkills,
        strengths: strengths,
        weaknesses: weaknesses,
        projects: projects,
        finalRecommendation: finalRecommendation,
        suggestions: suggestions,
        analyzedAt: analyzedAt,
        adminDecision: adminDecision ?? this.adminDecision,
        adminNotes: adminNotes ?? this.adminNotes,
      );
}
