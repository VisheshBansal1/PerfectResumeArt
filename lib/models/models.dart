// ─── User Model ───────────────────────────────────────────────
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'user' or 'admin'
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
        email: map['email'] ?? '',
        name: map['name'] ?? '',
        role: map['role'] ?? 'user',
        photoUrl: map['photoUrl'],
        createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'role': role,
        'photoUrl': photoUrl,
        'createdAt': createdAt,
      };

  UserModel copyWith({String? name, String? role, String? photoUrl}) => UserModel(
        uid: uid,
        email: email,
        name: name ?? this.name,
        role: role ?? this.role,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt,
      );
}

// ─── Job Model ────────────────────────────────────────────────
class JobModel {
  final String id;
  final String title;
  final String description;
  final List<String> requiredSkills;
  final List<String> preferredSkills;
  final int minExperience;
  final List<String> requiredProjectTypes;
  final String createdBy; // admin uid
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
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        requiredSkills: List<String>.from(map['requiredSkills'] ?? []),
        preferredSkills: List<String>.from(map['preferredSkills'] ?? []),
        minExperience: map['minExperience'] ?? 0,
        requiredProjectTypes: List<String>.from(map['requiredProjectTypes'] ?? []),
        createdBy: map['createdBy'] ?? '',
        createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
        isActive: map['isActive'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'requiredSkills': requiredSkills,
        'preferredSkills': preferredSkills,
        'minExperience': minExperience,
        'requiredProjectTypes': requiredProjectTypes,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'isActive': isActive,
      };
}

// ─── Resume Model ─────────────────────────────────────────────
// fileUrl is now nullable — we no longer upload to Firebase Storage.
// The file is processed locally; only extracted text + metadata are saved.
class ResumeModel {
  final String id;
  final String userId;
  final String fileName;
  final String? fileUrl; // null when stored without Firebase Storage
  final String fileType; // 'pdf' or 'image'
  final String extractedText;
  final DateTime uploadedAt;

  const ResumeModel({
    required this.id,
    required this.userId,
    required this.fileName,
    this.fileUrl, // optional
    required this.fileType,
    required this.extractedText,
    required this.uploadedAt,
  });

  factory ResumeModel.fromMap(Map<String, dynamic> map, String id) => ResumeModel(
        id: id,
        userId: map['userId'] ?? '',
        fileName: map['fileName'] ?? '',
        fileUrl: map['fileUrl'], // may be null
        fileType: map['fileType'] ?? 'pdf',
        extractedText: map['extractedText'] ?? '',
        uploadedAt: (map['uploadedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'fileName': fileName,
        'fileUrl': fileUrl, // stored as null in Firestore, that's fine
        'fileType': fileType,
        'extractedText': extractedText,
        'uploadedAt': uploadedAt,
      };
}

// ─── Analysis Models ──────────────────────────────────────────
class ProjectAnalysis {
  final String name;
  final int score;
  final List<String> issues;
  final List<String> suggestions;
  final String techStack;
  final String complexity; // 'Low' | 'Medium' | 'High'

  const ProjectAnalysis({
    required this.name,
    required this.score,
    required this.issues,
    required this.suggestions,
    required this.techStack,
    required this.complexity,
  });

  factory ProjectAnalysis.fromMap(Map<String, dynamic> map) => ProjectAnalysis(
        name: map['name'] ?? '',
        score: map['score'] ?? 0,
        issues: List<String>.from(map['issues'] ?? []),
        suggestions: List<String>.from(map['suggestions'] ?? []),
        techStack: map['techStack'] ?? '',
        complexity: map['complexity'] ?? 'Medium',
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

// analysisType: 'full' | 'ats_only' | 'custom_tech'
class AnalysisModel {
  final String id;
  final String userId;
  final String resumeId;
  final String jobId;
  final String jobTitle;
  final String analysisType; // 'full', 'ats_only', 'custom_tech'
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

  factory AnalysisModel.fromMap(Map<String, dynamic> map, String id) => AnalysisModel(
        id: id,
        userId: map['userId'] ?? '',
        resumeId: map['resumeId'] ?? '',
        jobId: map['jobId'] ?? '',
        jobTitle: map['jobTitle'] ?? '',
        analysisType: map['analysisType'] ?? 'full',
        matchScore: map['matchScore'] ?? 0,
        atsScore: map['atsScore'] ?? 0,
        projectScore: map['projectScore'] ?? 0,
        overallScore: map['overallScore'] ?? 0,
        missingSkills: List<String>.from(map['missingSkills'] ?? []),
        strengths: List<String>.from(map['strengths'] ?? []),
        weaknesses: List<String>.from(map['weaknesses'] ?? []),
        projects: (map['projects'] as List<dynamic>? ?? [])
            .map((p) => ProjectAnalysis.fromMap(p as Map<String, dynamic>))
            .toList(),
        finalRecommendation: map['finalRecommendation'] ?? 'Fail',
        suggestions: List<String>.from(map['suggestions'] ?? []),
        analyzedAt: (map['analyzedAt'] as dynamic)?.toDate() ?? DateTime.now(),
        adminDecision: map['adminDecision'],
        adminNotes: map['adminNotes'],
      );

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
        'analyzedAt': analyzedAt,
        'adminDecision': adminDecision,
        'adminNotes': adminNotes,
      };

  AnalysisModel copyWith({String? adminDecision, String? adminNotes}) => AnalysisModel(
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