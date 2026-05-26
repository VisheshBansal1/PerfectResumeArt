import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/models.dart';
import 'app_config.dart';

// ─── Document Types ────────────────────────────────────────────────────────────

enum _DocumentType {
  resume,
  certificate,
  degreeCertificate,
  idCard,
  passport,
  coverLetter,
  portfolioWebpage,
  transcript,
  offerLetter,
  payslip,
  marksheet,
  codeFile,
  blankOrGarbled,
  other,
}

extension _DocumentTypeX on _DocumentType {
  bool get isResume => this == _DocumentType.resume;

  String get label {
    switch (this) {
      case _DocumentType.resume:
        return 'Resume / CV';
      case _DocumentType.certificate:
        return 'Certificate / Award';
      case _DocumentType.degreeCertificate:
        return 'Degree Certificate';
      case _DocumentType.idCard:
        return 'ID Card / National ID';
      case _DocumentType.passport:
        return 'Passport';
      case _DocumentType.coverLetter:
        return 'Cover Letter';
      case _DocumentType.portfolioWebpage:
        return 'Portfolio / Webpage';
      case _DocumentType.transcript:
        return 'Academic Transcript';
      case _DocumentType.offerLetter:
        return 'Offer Letter / Contract';
      case _DocumentType.payslip:
        return 'Payslip / Salary Slip';
      case _DocumentType.marksheet:
        return 'Marksheet / Grade Report';
      case _DocumentType.codeFile:
        return 'Code / Technical File';
      case _DocumentType.blankOrGarbled:
        return 'Blank or Unreadable File';
      case _DocumentType.other:
        return 'Non-Resume Document';
    }
  }

  String get userMessage {
    switch (this) {
      case _DocumentType.resume:
        return '';
      case _DocumentType.certificate:
        return 'We detected a certificate or award document (e.g. Coursera, Udemy, AWS certification). '
            'Certificates cannot be analyzed as a resume. Please upload your actual resume or CV '
            'that shows your work experience, projects, education, and skills.';
      case _DocumentType.degreeCertificate:
        return 'We detected a degree or convocation certificate. '
            'Please upload your full resume or CV that includes your experience, projects, and skills '
            'alongside your education.';
      case _DocumentType.idCard:
        return 'We detected a national ID, Aadhaar card, or driver\'s license. '
            'This document cannot be analyzed. Please upload your resume or CV instead.';
      case _DocumentType.passport:
        return 'We detected a passport or travel document. '
            'This cannot be analyzed as a resume. Please upload your resume or CV instead.';
      case _DocumentType.coverLetter:
        return 'We detected a cover letter, not a resume. '
            'A cover letter alone cannot be analyzed — it doesn\'t contain the structured '
            'experience, skills, and project data needed for resume analysis. '
            'Please upload your actual resume or CV.';
      case _DocumentType.portfolioWebpage:
        return 'We detected what looks like a portfolio or webpage screenshot. '
            'Please upload a PDF or image of your resume or CV instead.';
      case _DocumentType.transcript:
        return 'We detected an academic transcript showing semester-wise grades. '
            'Transcripts cannot be analyzed as a resume. Please upload your resume or CV '
            'that summarizes your experience, skills, and projects.';
      case _DocumentType.offerLetter:
        return 'We detected an offer letter or employment contract. '
            'This cannot be analyzed as a resume. Please upload your resume or CV instead.';
      case _DocumentType.payslip:
        return 'We detected a payslip or salary document. '
            'This cannot be analyzed as a resume. Please upload your resume or CV instead.';
      case _DocumentType.marksheet:
        return 'We detected a marksheet or grade report. '
            'Please upload your resume or CV that lists your experience, skills, and projects.';
      case _DocumentType.codeFile:
        return 'We detected source code or a technical configuration file. '
            'Please upload your resume or CV in PDF, JPG, or PNG format instead.';
      case _DocumentType.blankOrGarbled:
        return 'The uploaded file appears to be blank, or text could not be extracted clearly. '
            'Try uploading a higher-quality scan, or use a PDF version of your resume '
            'for best OCR accuracy.';
      default:
        return 'The uploaded file doesn\'t appear to be a resume or CV. '
            'Please upload your resume or CV in PDF, JPG, or PNG format.';
    }
  }
}

// ─── Resume Signal Detector ────────────────────────────────────────────────────
//
// THE GOLDEN RULE: If a document has enough resume signals, it IS a resume —
// even if it also contains patterns that appear in other document types.
// Indian tech resumes often include CGPA, father's name, notice period, percentage
// of marks, roll number, etc. These alone must NEVER trigger a rejection.

class _ResumeSignalDetector {
  static final _emailRegex = RegExp(
    r'\b[\w.%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b',
  );
  static final _phoneRegex = RegExp(r'(\+?\d[\d\s\-(). ]{7,}\d)');
  static final _dateRangeRegex = RegExp(
    r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s.]+20\d\d',
    caseSensitive: false,
  );
  static final _yearRangeRegex = RegExp(
    r'20\d\d\s*[-–]\s*(20\d\d|present|current)',
    caseSensitive: false,
  );

  /// Returns a confidence score 0-10 for "this is a resume".
  /// Score ≥ 3 → treat as resume (conservative threshold by design).
  static int resumeScore(String text) {
    final lower = text.toLowerCase();
    int score = 0;

    // ── Tier-1 signals (weight 2 each) ─────────────────────────────────────
    // These are the most discriminating signals

    // Email address (almost every resume has one)
    if (_emailRegex.hasMatch(text)) score += 2;

    // Phone number
    if (_phoneRegex.hasMatch(text)) score += 1;

    // Work / Experience section header
    if (_matchesAny(lower, [
      'work experience',
      'professional experience',
      'employment history',
      'career history',
      'experience\n',
      '\nexperience',
      'experience:',
      'internship',
      'intern at ',
      'interned at',
      'trainee at',
      'worked as',
      'working as',
      'software engineer',
      'software developer',
      'full stack developer',
      'frontend developer',
      'backend developer',
      'mobile developer',
      'data scientist',
      'devops engineer',
      'product manager',
      'ux designer',
    ]))
      score += 2;

    // Skills / Technologies section
    if (_matchesAny(lower, [
      'technical skills',
      'skills:',
      'skills\n',
      '\nskills',
      'technologies:',
      'tech stack',
      'programming languages',
      'frameworks',
      'tools and technologies',
      'core competencies',
      'areas of expertise',
    ]))
      score += 2;

    // Projects section
    if (_matchesAny(lower, [
      'projects:',
      'projects\n',
      '\nprojects',
      'personal projects',
      'academic projects',
      'key projects',
      'side projects',
      'github.com/',
      'tech stack:',
      'deployed on',
      'live at http',
    ]))
      score += 2;

    // ── Tier-2 signals (weight 1 each) ─────────────────────────────────────

    // Date ranges typical of work/education history
    if (_dateRangeRegex.hasMatch(text) || _yearRangeRegex.hasMatch(text))
      score += 1;

    // LinkedIn / GitHub / Portfolio
    if (_matchesAny(lower, [
      'linkedin.com/in/',
      'github.com/',
      'portfolio',
      'leetcode',
      'hackerrank',
      'codeforces',
      'behance',
      'dribbble',
    ]))
      score += 1;

    // Education section
    if (_matchesAny(lower, [
      'education:',
      'education\n',
      '\neducation',
      'b.tech',
      'b.e.',
      'bachelor of technology',
      'bachelor of engineering',
      'm.tech',
      'master of technology',
      'bca',
      'mca',
      'b.sc',
      'mba',
      'pursuing',
      'expected graduation',
      'expected: 20',
    ]))
      score += 1;

    // Job objective / summary / profile (resume-specific section)
    if (_matchesAny(lower, [
      'objective:',
      'career objective',
      'professional summary',
      'summary:',
      'profile:',
      'about me',
      'seeking a',
      'seeking an',
      'looking for a',
      'aspiring',
    ]))
      score += 1;

    // Action verbs in bullet context (strong resume signal)
    if (_matchesAny(lower, [
      'developed',
      'built',
      'implemented',
      'designed',
      'deployed',
      'optimized',
      'integrated',
      'architected',
      'created',
      'maintained',
      'collaborated',
      'led the',
      'managed',
    ]))
      score += 1;

    // Certifications listed within a resume context (not standalone cert docs)
    if (_matchesAny(lower, [
      'certifications:',
      'achievements:',
      'awards:',
      'honors:',
      'publications:',
    ]))
      score += 1;

    return score;
  }

  static bool _matchesAny(String text, List<String> patterns) =>
      patterns.any((p) => text.contains(p));

  /// Any score ≥ 3 means the document is almost certainly a resume.
  static bool isDefinitelyResume(String text) => resumeScore(text) >= 3;
}

// ─── Heuristic Classifier ─────────────────────────────────────────────────────
//
// IMPORTANT DESIGN PRINCIPLE:
// This classifier uses a "deny-list" approach. It only rejects a document when
// there are VERY STRONG non-resume signals AND WEAK resume signals.
// When in doubt, return null → fall through to the AI classifier.
//
// Common false-positive triggers in Indian resumes that we deliberately IGNORE:
//   - CGPA, SGPA, grade point average (appear in Education section of resumes)
//   - Father's name, mother's name (appear in Personal Details section)
//   - Roll number, roll no (appear in Education section)
//   - Percentage of marks (appear in Education section)
//   - Notice period (appears in Career Objective / Summary)
//   - CTC, salary expectations (appear in objectives)
//   - Date of birth (appears in Personal Details)

class _HeuristicClassifier {
  static _DocumentType? classify(String text) {
    final lower = text.toLowerCase();
    final wordCount = text.trim().split(RegExp(r'\s+')).length;

    // ── Step 1: Blanks and garbled text (always reject, no override) ─────────
    if (wordCount < 25) return _DocumentType.blankOrGarbled;
    if (_garbledRatio(text) > 0.40) return _DocumentType.blankOrGarbled;

    // ── Step 2: Resume override check ────────────────────────────────────────
    // If the document has enough resume signals, classify it as resume
    // immediately — don't even run the non-resume checks.
    if (_ResumeSignalDetector.isDefinitelyResume(text)) return null;

    // ── Step 3: Non-resume document checks ───────────────────────────────────
    // Only run these when resume signals are WEAK or absent.
    // Each check requires MULTIPLE strong and specific signals to fire.

    // ID Card (very specific pattern, tiny word count, no work history)
    if (wordCount < 100 &&
        _countMatches(lower, [
              'unique identification number',
              'aadhaar',
              'voter id card',
              'driving licence',
              'driving license',
              'vehicle class',
              'license number',
              'permanent account number',
            ]) >=
            1)
      return _DocumentType.idCard;

    // Passport (very specific, usually tiny text)
    if (wordCount < 150 &&
        _countMatches(lower, [
              'passport no',
              'passport number',
              'machine readable zone',
              'mrz',
            ]) >=
            1 &&
        _matchesAny(lower, [
          'nationality',
          'place of birth',
          'date of expiry',
        ])) {
      return _DocumentType.passport;
    }

    // Online Certificate / Award (standalone cert, NOT embedded in resume)
    // Requires: cert-specific language + issuing authority + NO work experience signals
    if (_countMatches(lower, [
              'certificate of completion',
              'this is to certify that',
              'has successfully completed',
              'has successfully passed',
              'certificate of achievement',
              'certificate of participation',
              'is hereby certified',
              'udemy certificate',
              'coursera certificate',
              'linkedin learning certificate',
              'completion certificate',
              'certificate of proficiency',
            ]) >=
            1 &&
        !_ResumeSignalDetector.isDefinitelyResume(text) &&
        wordCount < 250) {
      return _DocumentType.certificate;
    }

    // Degree/Convocation Certificate (NOT a resume with degree mentioned)
    // Requires very formal university language + NO experience/projects
    if (_countMatches(lower, [
              'is hereby awarded the degree',
              'has been conferred the degree',
              'convocation ceremony',
              'chancellor of the university',
              'vice-chancellor',
            ]) >=
            1 &&
        !_matchesAny(lower, [
          'experience',
          'project',
          'skills',
          'internship',
        ])) {
      return _DocumentType.degreeCertificate;
    }

    // Cover Letter (must have greeting + closing salutation + no resume sections)
    if (_countMatches(lower, [
              'dear hiring manager',
              'dear recruiter',
              'dear sir or madam',
              'dear sir/madam',
              'to whom it may concern',
              'i am writing to apply',
              'i am writing to express my interest',
              'i would like to apply for',
              'i am interested in the position of',
              'please find my resume attached',
              'please find attached my resume',
            ]) >=
            1 &&
        _matchesAny(lower, [
          'sincerely,',
          'yours sincerely',
          'yours faithfully',
          'warm regards,',
          'best regards,',
          'looking forward to hearing from you',
        ]) &&
        wordCount < 500 &&
        !_matchesAny(lower, [
          'technical skills',
          'projects:',
          'work experience',
        ])) {
      return _DocumentType.coverLetter;
    }

    // Payslip (VERY specific: must have pay-related fields in a structured layout)
    // Requires 3+ specific payslip-only fields
    if (_countMatches(lower, [
              'net pay',
              'gross pay',
              'net salary',
              'gross salary',
              'basic pay',
              'house rent allowance',
              'provident fund',
              'professional tax',
              'tds deducted',
              'deductions total',
              'employee code',
              'pay period',
              'pay slip',
              'salary slip',
              'payslip for the month',
            ]) >=
            3 &&
        wordCount < 350 &&
        !_ResumeSignalDetector.isDefinitelyResume(text)) {
      return _DocumentType.payslip;
    }

    // Offer Letter (specific employment terms document)
    // Requires 2+ very-specific offer-letter phrases
    if (_countMatches(lower, [
              'we are pleased to offer you',
              'we are delighted to offer you',
              'letter of appointment',
              'this letter of offer',
              'letter of offer of employment',
              'your appointment as',
              'terms and conditions of your employment',
              'compensation and benefits',
              'annual cost to company',
              'annual ctc',
            ]) >=
            2 &&
        !_ResumeSignalDetector.isDefinitelyResume(text)) {
      return _DocumentType.offerLetter;
    }

    // Academic Transcript (semester-wise grade table, NOT education section in resume)
    // Requires VERY specific transcript-only patterns
    if (_countMatches(lower, [
              'transcript of records',
              'academic transcript',
              'official transcript',
              'semester i grades',
              'semester ii grades',
              'end semester examination',
              'grade card',
              'result notification',
            ]) >=
            1 &&
        _countMatches(lower, [
              'subject code',
              'credit hours',
              'credits earned',
              'grade points',
              'letter grade',
            ]) >=
            2 &&
        !_ResumeSignalDetector.isDefinitelyResume(text)) {
      return _DocumentType.transcript;
    }

    // Marksheet (board exam result, NOT education section in resume)
    // Requires very specific marksheet-only patterns
    if (_countMatches(lower, [
              'marks obtained out of',
              'maximum marks',
              'pass marks',
              'board of secondary education',
              'board of higher secondary',
              'central board of secondary education',
              'cbse',
              'hsc board',
              'ssc board',
              'examination result',
              'result gazette',
            ]) >=
            2 &&
        wordCount < 400 &&
        !_ResumeSignalDetector.isDefinitelyResume(text)) {
      return _DocumentType.marksheet;
    }

    // Source code / config file
    if (_countMatches(text, [
              'import ',
              'function ',
              'const ',
              'export default',
              'class ',
              'def ',
              '#!/',
              '<?php',
              '<html>',
              'package main',
            ]) >=
            4 &&
        !_matchesAny(lower, ['experience', 'education', 'skills'])) {
      return _DocumentType.codeFile;
    }

    // Default: not enough signal → let AI decide
    return null;
  }

  static bool _matchesAny(String text, List<String> patterns) =>
      patterns.any((p) => text.contains(p));

  static int _countMatches(String text, List<String> patterns) =>
      patterns.where((p) => text.contains(p)).length;

  static double _garbledRatio(String text) {
    if (text.isEmpty) return 1.0;
    final garbage = text.runes
        .where((r) => (r < 32 && r != 10 && r != 13 && r != 9) || r > 65533)
        .length;
    return garbage / text.length;
  }
}

// ─── Service ───────────────────────────────────────────────────────────────────
class AiService {
  // GROQ_API_KEY and Groq URL removed — AI calls now go through backend proxy.
  // See: https://resume-ai-backend-bwzx.onrender.com/api/ai/chat

  static const String _primaryModel = 'llama-3.3-70b-versatile';
  static const String _classifierModel = 'llama-3.1-8b-instant';

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// Full analysis against an admin-created job role.
  Future<AnalysisModel> analyzeResume({
    required String resumeText,
    required JobModel job,
    required String userId,
    required String resumeId,
    String analysisType = 'full',
  }) async {
    final docType = await _detectDocumentType(resumeText);
    if (!docType.isResume) {
      return _notResumeModel(
        userId: userId,
        resumeId: resumeId,
        jobId: job.id,
        jobTitle: job.title,
        analysisType: analysisType,
        docType: docType,
      );
    }
    final response = await _callGroqWithRetry(
      _buildFullAnalysisPrompt(resumeText, job),
      model: _primaryModel,
      maxTokens: 4096,
    );
    return _parseAnalysisResponse(
      response,
      userId,
      resumeId,
      job,
      analysisType,
    );
  }

  /// Custom tech stack analysis.
  Future<AnalysisModel> analyzeWithCustomTech({
    required String resumeText,
    required String jobTitle,
    required List<String> requiredSkills,
    required String description,
    required String userId,
    required String resumeId,
  }) async {
    final docType = await _detectDocumentType(resumeText);
    final virtualJob = JobModel(
      id: 'custom',
      title: jobTitle,
      description: description.isEmpty
          ? 'Analyze this resume against the specified technology stack.'
          : description,
      requiredSkills: requiredSkills,
      preferredSkills: [],
      minExperience: 0,
      requiredProjectTypes: [],
      createdBy: userId,
      createdAt: DateTime.now(),
    );

    if (!docType.isResume) {
      return _notResumeModel(
        userId: userId,
        resumeId: resumeId,
        jobId: 'custom',
        jobTitle: jobTitle,
        analysisType: 'custom_tech',
        docType: docType,
      );
    }

    final response = await _callGroqWithRetry(
      _buildCustomTechPrompt(resumeText, jobTitle, requiredSkills, description),
      model: _primaryModel,
      maxTokens: 4096,
    );
    return _parseAnalysisResponse(
      response,
      userId,
      resumeId,
      virtualJob,
      'custom_tech',
    );
  }

  /// ATS-only analysis.
  Future<AnalysisModel> analyzeAtsOnly({
    required String resumeText,
    required String userId,
    required String resumeId,
  }) async {
    final docType = await _detectDocumentType(resumeText);
    if (!docType.isResume) {
      return _notResumeModel(
        userId: userId,
        resumeId: resumeId,
        jobId: 'ats_check',
        jobTitle: 'ATS Compatibility Check',
        analysisType: 'ats_only',
        docType: docType,
      );
    }

    final response = await _callGroqWithRetry(
      _buildAtsOnlyPrompt(resumeText),
      model: _primaryModel,
      maxTokens: 4096,
    );
    return _parseAtsResponse(response, userId, resumeId);
  }

  /// Rewrites a bullet point into 3 stronger, ATS-optimised variants.
  Future<List<String>> rewriteBulletPoint(
    String original,
    String jobTitle,
  ) async {
    final prompt =
        '''
You are an expert resume writer. Rewrite this bullet point to be stronger, ATS-optimized,
and impactful for a $jobTitle role.

Rules:
- Start with a powerful action verb (Built, Engineered, Reduced, Increased, Shipped,
  Architected, Deployed, Automated, Launched, Optimized, Delivered, Integrated)
- Add quantifiable impact — estimate with "~" if exact number unknown
- Be specific about the technology and the outcome
- Maximum 20 words per bullet
- Never start with "I" or use passive voice

Original: $original

Provide exactly 3 alternative rewrites. Respond ONLY as valid JSON, no markdown:
{"rewrites": ["option1", "option2", "option3"]}
''';
    final response = await _callGroqWithRetry(
      prompt,
      model: _primaryModel,
      maxTokens: 512,
    );
    final data = _decodeJson(response);
    return _parseStringList(data, 'rewrites');
  }

  // ─── Document Type Detection ──────────────────────────────────────────────────
  //
  // Three-stage pipeline:
  //   Stage 0: Resume signal scoring  → if score ≥ 3, it IS a resume, skip all else
  //   Stage 1: Heuristic pre-filter   → catch obvious non-resumes without API cost
  //   Stage 2: AI classifier          → only for genuinely ambiguous documents
  //
  // This ordering prevents the most common false-reject scenario: a valid resume
  // that mentions CGPA, father's name, percentage, notice period, etc.

  Future<_DocumentType> _detectDocumentType(String text) async {
    // ── Stage 0: Fast resume signal check ───────────────────────────────────
    // If the document has 3+ strong resume signals, it is a resume.
    // This check fires BEFORE any heuristics to prevent false rejects.
    if (_ResumeSignalDetector.isDefinitelyResume(text)) {
      return _DocumentType.resume;
    }

    // ── Stage 1: Heuristic pre-filter ───────────────────────────────────────
    // Only runs when resume signals are weak — handles blanks, IDs, etc.
    final heuristic = _HeuristicClassifier.classify(text);
    if (heuristic != null) return heuristic;

    // ── Stage 2: AI classifier (only for truly ambiguous documents) ─────────
    if (text.trim().length < 30) return _DocumentType.blankOrGarbled;
    try {
      final truncated = text.length > 3000 ? text.substring(0, 3000) : text;
      final response = await _callGroq(
        _classifierPrompt(truncated),
        model: _classifierModel,
        maxTokens: 120,
      );
      final data = _decodeJson(response);
      final typeStr = (data['type'] as String? ?? 'resume')
          .toLowerCase()
          .trim();
      final confidence = (data['confidence'] as num?)?.toInt() ?? 0;

      // Conservative: only reject if AI is VERY confident (≥ 75%) it's not a resume.
      // Any doubt → assume resume. False accepts are far less harmful than false rejects.
      if (typeStr == 'resume' || confidence < 75) {
        return _DocumentType.resume;
      }
      return _parseDocumentType(typeStr);
    } catch (_) {
      // Any classifier error → assume resume to avoid false rejection
      return _DocumentType.resume;
    }
  }

  String _classifierPrompt(String text) =>
      '''
You are a document-type classifier. Your #1 priority is to NOT falsely reject real resumes.

CRITICAL RULES:
1. If you see an email + any of {work experience, projects, skills section} → it is ALWAYS a "resume"
2. CGPA, SGPA, percentage of marks, roll number, father's name, notice period, CTC expectations
   inside a document that also has work/skills/projects = RESUME, not a transcript or marksheet
3. When genuinely unsure, ALWAYS return "resume" with confidence 50

Return ONLY a JSON object. No explanation. No markdown.
Example: {"type":"resume","confidence":92}

The "type" field must be EXACTLY one of:
  "resume"             → Has name + email/phone + at least 2 of: {work experience, projects, education, skills}
  "certificate"        → STANDALONE online course certificate ONLY. Must have: issuing org + "has successfully completed" + student name + NO experience/skills/projects sections
  "degree_certificate" → STANDALONE university convocation degree. Must have: "is hereby awarded" or "has been conferred" + chancellor/registrar + NO skills or projects
  "id_card"            → Aadhaar / voter ID / national ID. Very short, has ID number + DOB. NOT a resume.
  "passport"           → Passport document. Has passport number + nationality + MRZ. NOT a resume.
  "cover_letter"       → Cover letter with "Dear [Hiring Manager/Recruiter]" greeting AND closing salutation AND NO resume sections (no skills, no projects list)
  "transcript"         → Formal academic transcript with SGPA/CGPA table + subject codes + credit hours. NO work experience present.
  "offer_letter"       → Formal offer/appointment letter. Has "we are pleased to offer you" + joining date + notice period + salary breakup. NOT a resume.
  "payslip"            → Salary slip. Has gross pay + net pay + deductions table. NOT a resume.
  "marksheet"          → School/board exam marksheet with marks obtained + max marks + subject list. NOT a resume.
  "code_file"          → Source code or config file. Has import statements, function definitions, etc.
  "blank_garbled"      → Empty, random symbols, OCR garbage, or fewer than 30 meaningful words
  "other"              → Anything clearly not a resume that doesn't match above types

Confidence rules (0-100):
  90-100: Multiple unmistakable signals, zero ambiguity
  75-89:  Clear signals but 1-2 elements that could also appear in a resume
  50-74:  Ambiguous — return "resume" if in doubt
  <50:    Genuinely unsure → MUST return "resume"

DOCUMENT TEXT:
$text
''';

  _DocumentType _parseDocumentType(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'resume':
        return _DocumentType.resume;
      case 'certificate':
        return _DocumentType.certificate;
      case 'degree_certificate':
        return _DocumentType.degreeCertificate;
      case 'id_card':
        return _DocumentType.idCard;
      case 'passport':
        return _DocumentType.passport;
      case 'cover_letter':
        return _DocumentType.coverLetter;
      case 'portfolio':
        return _DocumentType.portfolioWebpage;
      case 'transcript':
        return _DocumentType.transcript;
      case 'offer_letter':
        return _DocumentType.offerLetter;
      case 'payslip':
        return _DocumentType.payslip;
      case 'marksheet':
        return _DocumentType.marksheet;
      case 'code_file':
        return _DocumentType.codeFile;
      case 'blank_garbled':
        return _DocumentType.blankOrGarbled;
      default:
        return _DocumentType.other;
    }
  }

  // ─── Not-a-Resume Model Builder ───────────────────────────────────────────────

  AnalysisModel _notResumeModel({
    required String userId,
    required String resumeId,
    required String jobId,
    required String jobTitle,
    required String analysisType,
    required _DocumentType docType,
  }) => AnalysisModel(
    id: '',
    userId: userId,
    resumeId: resumeId,
    jobId: jobId,
    jobTitle: 'Detected: ${docType.label}',
    analysisType: analysisType,
    matchScore: 0,
    atsScore: 0,
    projectScore: 0,
    overallScore: 0,
    missingSkills: [docType.userMessage],
    strengths: [],
    weaknesses: ['File identified as "${docType.label}" — not a resume or CV.'],
    projects: [],
    finalRecommendation: 'Not a Resume',
    suggestions: [
      'Upload your resume or CV in PDF, JPG, or PNG format.',
      'Your resume should contain: your name, contact info (email + phone), '
          'work experience or personal projects, education, and a skills section.',
      'Tip: Export from Google Docs, Microsoft Word, or Canva as PDF for best results.',
    ],
    analyzedAt: DateTime.now(),
  );

  // ─── Analysis Prompts ──────────────────────────────────────────────────────────

  String _buildFullAnalysisPrompt(String resumeText, JobModel job) =>
      '''
You are a Principal-level technical recruiter and engineering hiring manager with 20+ years of experience
at top-tier tech companies. You have reviewed over 10,000 developer resumes.
You give honest, precise feedback — not encouraging, not harsh, just accurate.

═══════════════════════════════════════════════════
TARGET ROLE
═══════════════════════════════════════════════════
Title:             ${job.title}
Description:       ${job.description}
Required Skills:   ${job.requiredSkills.join(', ')}
Preferred Skills:  ${job.preferredSkills.isNotEmpty ? job.preferredSkills.join(', ') : 'None specified'}
Min Experience:    ${job.minExperience} year(s)
Required Projects: ${job.requiredProjectTypes.isNotEmpty ? job.requiredProjectTypes.join(', ') : 'None specified'}

═══════════════════════════════════════════════════
RESUME TEXT
═══════════════════════════════════════════════════
$resumeText

═══════════════════════════════════════════════════
ANALYSIS FRAMEWORK
═══════════════════════════════════════════════════

STEP 1 — SKILL INFERENCE ENGINE
For each required skill, evaluate three evidence levels:
  DIRECT   (100%): Skill named explicitly in experience, projects, or skills section
  INFERRED  (70%): Strongly implied by adjacent technologies
    "BLoC/Riverpod"  → Dart Streams, reactive patterns, state isolation
    "Firebase RTDB"  → NoSQL, real-time sync, client-side querying
    "Next.js"        → React, SSR, Node.js fundamentals, Vercel
    "Spring Boot"    → Java, REST APIs, dependency injection, Maven/Gradle
    "Redux/Zustand"  → Immutable state, action/reducer, unidirectional flow
    "Docker Compose" → Containerization, service orchestration
  PARTIAL   (40%): Listed in Skills section only, no project usage evidence
  ABSENT     (0%): No direct or inferential path
  RULE: Never penalize inferred skills. Only mark MISSING if absent at 0%.

STEP 2 — EXPERIENCE DEPTH CALIBRATION
These are very different — do not score them the same:
  Shallow:  "Worked with Flutter"                              → junior signal
  Moderate: "Built 2 Flutter apps using BLoC and Firebase"    → mid signal
  Deep:     "Shipped Flutter app: 8K+ downloads, 4.7★ rating" → senior signal
Depth multipliers:
  0 metrics anywhere → cap skill depth contribution at 40%
  1–2 metrics        → cap at 70%
  3+ metrics spread across multiple projects → up to 100%

STEP 3 — PROJECT QUALITY SCORING (score each project 0–100)
Score on 5 dimensions (20 points each):
  SCOPE:        Tutorial/clone=0-6; hobby=7-13; solves real problem with users=14-20
  ARCHITECTURE: No pattern=0-6; basic MVC/MVVM=7-13; clean arch, well-layered=14-20
  DEPTH:        Single feature=0-6; 2-3 integrations=7-13; multi-integration (auth+DB+storage+push)=14-20
  OUTCOME:      Never shipped=0-5; shipped no data=6-10; live with any metric=11-16; live with strong metrics=17-20
  RELEVANCE:    Unrelated to role=0-6; partially related=7-13; directly demonstrates role tech=14-20

STEP 4 — SCORE CALCULATION
  matchScore:   Weighted average of all required skills by evidence level (Step 1)
  atsScore:     Sum of the following (max 100):
                  +20 Standard section headers (Experience, Education, Skills, Projects, Summary)
                  +20 ≥40% of bullets have a number, %, or concrete outcome
                  +15 Consistent date format throughout
                  +15 Complete contact block at top (name + email + phone + LinkedIn/GitHub)
                  +15 Action verbs starting bullets
                  +15 No tables, columns, graphics, or text boxes
  projectScore: Average of all project scores from Step 3
  overallScore: EXACTLY ROUND(matchScore × 0.45 + projectScore × 0.35 + atsScore × 0.20)
                Verify your arithmetic. Do NOT generously round up.

STEP 5 — RECOMMENDATION (strict thresholds)
  "High Potential": overallScore ≥ 78 AND matchScore ≥ 80 AND ≥1 project scored ≥ 75
  "Pass":           overallScore ≥ 55 AND ≤1 critical required skill absent
  "Fail":           overallScore < 55 OR 2+ critical required skills absent with no inference path

STEP 6 — FEEDBACK QUALITY
  Strength entries: cite specific project name + metric or exact resume line
  Weakness entries: explain why this gap specifically hurts this candidate for ${job.title}
  Suggestion entries: include a concrete before/after example rewrite
  Missing skill entries: state the evidence level found and the exact gap

═══════════════════════════════════════════════════
OUTPUT — Valid JSON only. No markdown. No text outside the JSON.
═══════════════════════════════════════════════════
{
  "matchScore": <integer 0-100>,
  "atsScore": <integer 0-100>,
  "projectScore": <integer 0-100>,
  "overallScore": <integer 0-100, must = ROUND(match×0.45 + project×0.35 + ats×0.20)>,
  "missingSkills": [
    "SkillName — gap level: critical|moderate|minor — evidence: none|partial inference — why it matters for ${job.title}"
  ],
  "strengths": [
    "Specific strength — evidence: project name, metric, or exact resume line"
  ],
  "weaknesses": [
    "Specific weakness — impact: why this gap hurts this candidate for ${job.title}"
  ],
  "projects": [
    {
      "name": "Exact project name from resume",
      "score": <0-100>,
      "techStack": "all detected technologies (direct + inferred), comma-separated",
      "complexity": "Low|Medium|High",
      "issues": ["Specific technical concern: what's missing and why it matters"],
      "suggestions": ["BEFORE: [original line] → AFTER: [stronger rewritten version with metrics]"]
    }
  ],
  "finalRecommendation": "Pass|Fail|High Potential",
  "suggestions": [
    "Priority improvement — BEFORE: [current line] → AFTER: [improved version with metrics]"
  ]
}
''';

  String _buildCustomTechPrompt(
    String resumeText,
    String jobTitle,
    List<String> skills,
    String description,
  ) {
    final skillList = skills.join(', ');
    return '''
You are a Principal Engineer and technical hiring lead with 15+ years evaluating candidates
for specific technology stacks. You are precise, not encouraging.

═══════════════════════════════════════════════════
TARGET ROLE & REQUIRED STACK
═══════════════════════════════════════════════════
Role/Title:            $jobTitle
Required Technologies: $skillList
${description.isNotEmpty ? 'Additional Context:   $description' : ''}

═══════════════════════════════════════════════════
RESUME TEXT
═══════════════════════════════════════════════════
$resumeText

═══════════════════════════════════════════════════
THREE-LEVEL EVIDENCE FRAMEWORK
═══════════════════════════════════════════════════
For EACH technology in [$skillList], evaluate:

  LEVEL 1 — DIRECT (100%): Explicitly named in a project, role, or skills section
  LEVEL 2 — INFERRED (70%): Strongly implied by adjacent skills
    "Firebase RTDB" → NoSQL, real-time sync
    "BLoC/Riverpod" → Dart Streams, reactive patterns
    "Redux/Zustand"  → Immutable state, action/reducer
    "Spring Boot"    → Java, REST APIs, dependency injection
    "Docker Compose" → Containerization, service orchestration
  LEVEL 3 — DEPTH CEILING:
    Skills list only                      → max 50% confidence
    1 project, minimal detail             → max 65% confidence
    1 project with context                → max 80% confidence
    2+ projects or production + metrics   → max 100% confidence

SCORING:
  matchScore:   Average confidence across ALL required technologies
  atsScore:     Resume format quality (0-100):
                  +20 Standard section headers
                  +20 ≥40% of bullets quantified
                  +15 Consistent dates
                  +15 Complete contact block
                  +15 Action verbs on bullets
                  +15 No tables/columns/graphics
  projectScore: How directly projects demonstrate this stack
  overallScore: EXACTLY ROUND(matchScore × 0.50 + projectScore × 0.35 + atsScore × 0.15)

RECOMMENDATION:
  "High Potential": matchScore ≥ 80 AND ≥1 project directly uses ≥2 required technologies
  "Pass":           matchScore ≥ 55 AND missing techs are learnable (not foundational)
  "Fail":           matchScore < 55 OR missing core foundational techs with no inference path

═══════════════════════════════════════════════════
OUTPUT — Valid JSON only. No markdown. No text outside the JSON.
═══════════════════════════════════════════════════
{
  "matchScore": <integer 0-100>,
  "atsScore": <integer 0-100>,
  "projectScore": <integer 0-100>,
  "overallScore": <integer 0-100>,
  "missingSkills": [
    "TechName — level: no evidence|partial inference|direct but shallow — inference chain: [result]"
  ],
  "strengths": [
    "TechName — confidence: Level 1|2 — evidence: specific project or context"
  ],
  "weaknesses": [
    "Gap — inference failed: [reason] — impact on role: [why this tech matters]"
  ],
  "projects": [
    {
      "name": "Project name",
      "score": <0-100>,
      "techStack": "all detected technologies for this project",
      "complexity": "Low|Medium|High",
      "issues": ["Stack-fit concern: what's missing from this project for the target stack"],
      "suggestions": ["BEFORE: [original] → AFTER: [version that better demonstrates required stack]"]
    }
  ],
  "finalRecommendation": "Pass|Fail|High Potential",
  "suggestions": [
    "Highest-priority gap closure: specific change to make — with before/after example"
  ]
}
''';
  }

  String _buildAtsOnlyPrompt(String resumeText) =>
      '''
You are a certified ATS specialist who has configured Workday, Greenhouse, Lever, iCIMS, and Taleo.
You know exactly how these systems tokenize, parse, rank, and filter resumes.
Deliver a surgical, honest ATS audit. Find what will cause this resume to be filtered out.

═══════════════════════════════════════════════════
RESUME TEXT
═══════════════════════════════════════════════════
$resumeText

═══════════════════════════════════════════════════
ATS AUDIT — 4 SCORED DIMENSIONS (100 points total)
═══════════════════════════════════════════════════

DIMENSION 1 — PARSEABILITY (30 points):
  +10: Standard section headers:
       "Experience" or "Work Experience" (not "My Journey")
       "Education" (not "Academic Background")
       "Skills" or "Technical Skills" (not "My Toolkit")
       "Projects" (not "Things I Built")
  +8:  Consistent, parseable dates throughout (MM/YYYY or "Month Year")
       Failures: "2 years ago", "Ongoing", mixed formats
  +7:  Contact block at very top: full name + email + phone + LinkedIn or GitHub
  +5:  No tables, multi-column layouts, text boxes, headers/footers, embedded graphics

DIMENSION 2 — KEYWORD STRATEGY (25 points):
  +10: Keywords appear in context of real achievements, not only in a Skills dump
  +8:  Full technology names + abbreviations used together (e.g. "JavaScript (JS)")
  +7:  Industry action verbs at bullet starts: Built, Deployed, Automated, Reduced, etc.

DIMENSION 3 — QUANTIFIED IMPACT (25 points):
  +15: ≥40% of bullets contain a number, %, timeframe, or concrete outcome
  +10: Quality of metrics:
       Weak: "built an app" (0 weight)
       Medium: "built an app with 100 users" (partial weight)
       Strong: "Built Flutter app: 8,000+ downloads, 4.7★, 500 DAU" (full weight)

DIMENSION 4 — STRUCTURE & FORMAT (20 points):
  +8:  Appropriate length for experience level
  +7:  Consistent visual hierarchy (headers bolder than body)
  +5:  No orphaned lines, erratic capitalization, or mixed bullet styles

FAILURE SEVERITY:
  CRITICAL: Causes automatic rejection or parse failure (multi-column, missing contact, garbled headers)
  HIGH:     Significantly lowers ranking vs. equivalent candidates
  MEDIUM:   Reduces ranking in competitive pools
  LOW:      Minor improvements for marginal boost

RECOMMENDATION:
  "High Potential": atsScore ≥ 80
  "Pass":           atsScore 58-79
  "Fail":           atsScore < 58

═══════════════════════════════════════════════════
OUTPUT — Valid JSON only. No markdown. No text outside the JSON.
═══════════════════════════════════════════════════
{
  "matchScore": 0,
  "atsScore": <integer 0-100>,
  "projectScore": <integer 0-100>,
  "overallScore": <same as atsScore>,
  "missingSkills": [
    "Missing element — severity: critical|high|medium|low — ATS impact: [exact mechanism]"
  ],
  "strengths": [
    "ATS-friendly element — cite the exact section or line demonstrating it"
  ],
  "weaknesses": [
    "ATS failure — severity: critical|high|medium|low — mechanism: [how this hurts parse or rank]"
  ],
  "projects": [
    {
      "name": "Project name or \\"Projects Section\\"",
      "score": <0-100>,
      "techStack": "technologies found",
      "complexity": "Low|Medium|High",
      "issues": ["ATS-specific issue with this project entry"],
      "suggestions": ["BEFORE: [current text] → AFTER: [stronger version with metrics and keywords]"]
    }
  ],
  "finalRecommendation": "Pass|Fail|High Potential",
  "suggestions": [
    "Priority fix — severity: critical|high|medium|low — BEFORE: [current] → AFTER: [fixed]"
  ]
}
''';

  // ─── Groq API Call ────────────────────────────────────────────────────────────

  /// Single API call with no retry.
  /// Sends [prompt] to the backend proxy (/api/ai/chat) instead of calling
  /// Groq directly. GROQ_API_KEY stays on the Render server — never exposed
  /// in the Flutter web bundle.
  Future<String> _callGroq(
    String prompt, {
    required String model,
    required int maxTokens,
  }) async {
    final backendUrl = AppConfig.backendUrl;
    if (backendUrl.isEmpty) {
      throw const AiException(
        'Backend URL not configured. Pass --dart-define=BACKEND_URL=... at build time.',
      );
    }

    final uri = Uri.parse('$backendUrl/api/ai/chat');

    late http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'prompt': prompt,
              'model': model,
              'maxTokens': maxTokens,
            }),
          )
          .timeout(
            const Duration(seconds: 95),
            onTimeout: () =>
                throw const AiException('Request timed out. Please try again.'),
          );
    } on AiException {
      rethrow;
    } catch (e) {
      throw AiException('Network error: ${e.toString()}');
    }

    // Backend returns { success, content } or { success, error }
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AiException(
        'Invalid response from server (${response.statusCode}).',
      );
    }

    if (response.statusCode != 200 || data['success'] != true) {
      final error = data['error'] as String? ?? 'AI service error.';
      throw AiException(error);
    }

    final content = data['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw const AiException(
        'Empty response from AI service. Please try again.',
      );
    }
    return content;
  }

  /// API call with one automatic retry on transient failures (429, 503, timeout).
  Future<String> _callGroqWithRetry(
    String prompt, {
    required String model,
    required int maxTokens,
    int retries = 1,
  }) async {
    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        return await _callGroq(prompt, model: model, maxTokens: maxTokens);
      } on AiException catch (e) {
        // Only retry on transient errors
        final isTransient =
            e.message.contains('timed out') ||
            e.message.contains('Rate limit') ||
            e.message.contains('temporarily unavailable');
        if (attempt < retries && isTransient) {
          // Brief back-off before retry
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }
    throw const AiException('All retry attempts failed. Please try again.');
  }

  // ignore: unused_element
  // Previously used for direct Groq calls — now handled by backend proxy.
  String _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        break;
      case 400:
        throw const AiException(
          'Invalid request. Please try again with a different file.',
        );
      case 401:
        throw const AiException(
          'Invalid API key. Check your GROQ_API_KEY configuration.',
        );
      case 413:
        throw const AiException(
          'Resume text is too long. Try a shorter or cleaner PDF.',
        );
      case 429:
        throw const AiException(
          'Rate limit reached. Please wait a moment and try again.',
        );
      case 503:
        throw const AiException(
          'AI service is temporarily unavailable. Please try again shortly.',
        );
      default:
        throw AiException(
          'AI service error (${response.statusCode}). Please try again.',
        );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = data['choices']?[0]?['message']?['content'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw const AiException(
        'Empty response from AI service. Please try again.',
      );
    }
    return text;
  }

  // ─── Response Parsers ──────────────────────────────────────────────────────────

  AnalysisModel _parseAnalysisResponse(
    String jsonText,
    String userId,
    String resumeId,
    JobModel job,
    String analysisType,
  ) {
    try {
      final data = _decodeJson(jsonText);
      final matchScore = _clamp(data['matchScore']);
      final atsScore = _clamp(data['atsScore']);
      final projectScore = _clamp(data['projectScore']);
      // Recalculate overallScore server-side to prevent AI rounding games
      final overallScore = _clamp(
        data['overallScore'] ??
            (matchScore * 0.45 + projectScore * 0.35 + atsScore * 0.20).round(),
      );
      final aiRec = data['finalRecommendation'] as String? ?? 'Fail';

      return AnalysisModel(
        id: '',
        userId: userId,
        resumeId: resumeId,
        jobId: job.id,
        jobTitle: job.title,
        analysisType: analysisType,
        matchScore: matchScore,
        atsScore: atsScore,
        projectScore: projectScore,
        overallScore: overallScore,
        missingSkills: _parseStringList(data, 'missingSkills'),
        strengths: _parseStringList(data, 'strengths'),
        weaknesses: _parseStringList(data, 'weaknesses'),
        projects: _parseProjects(data),
        finalRecommendation: _enforceRecommendation(aiRec, overallScore),
        suggestions: _parseStringList(data, 'suggestions'),
        analyzedAt: DateTime.now(),
      );
    } catch (e) {
      throw AiException('Failed to parse AI response: $e\nRaw: $jsonText');
    }
  }

  AnalysisModel _parseAtsResponse(
    String jsonText,
    String userId,
    String resumeId,
  ) {
    try {
      final data = _decodeJson(jsonText);
      final atsScore = _clamp(data['atsScore']);
      final overallScore = _clamp(data['overallScore'] ?? data['atsScore']);
      final aiRec = data['finalRecommendation'] as String? ?? 'Fail';

      return AnalysisModel(
        id: '',
        userId: userId,
        resumeId: resumeId,
        jobId: 'ats_check',
        jobTitle: 'ATS Compatibility Check',
        analysisType: 'ats_only',
        matchScore: 0,
        atsScore: atsScore,
        projectScore: _clamp(data['projectScore']),
        overallScore: overallScore,
        missingSkills: _parseStringList(data, 'missingSkills'),
        strengths: _parseStringList(data, 'strengths'),
        weaknesses: _parseStringList(data, 'weaknesses'),
        projects: _parseProjects(data),
        finalRecommendation: _enforceRecommendation(aiRec, atsScore),
        suggestions: _parseStringList(data, 'suggestions'),
        analyzedAt: DateTime.now(),
      );
    } catch (e) {
      throw AiException('Failed to parse ATS response: $e\nRaw: $jsonText');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  /// Hard score gates the AI cannot override.
  String _enforceRecommendation(String aiRec, int score) {
    if (aiRec == 'Not a Resume') return 'Not a Resume';
    if (score >= 78) {
      return aiRec == 'High Potential' ? 'High Potential' : 'Pass';
    }
    if (score >= 55) return 'Pass';
    return 'Fail';
  }

  /// Robust JSON extraction — handles markdown fences, leading text, trailing text.
  Map<String, dynamic> _decodeJson(String raw) {
    // Remove markdown code fences
    String clean = raw
        .replaceAll('```json', '')
        .replaceAll('```dart', '')
        .replaceAll('```', '')
        .trim();

    // Find the outermost JSON object
    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      clean = clean.substring(start, end + 1);
    }

    try {
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      // Last resort: try to fix common JSON issues
      clean = clean
          .replaceAll(RegExp(r',\s*}'), '}') // trailing commas in objects
          .replaceAll(RegExp(r',\s*\]'), ']'); // trailing commas in arrays
      return jsonDecode(clean) as Map<String, dynamic>;
    }
  }

  List<ProjectAnalysis> _parseProjects(Map<String, dynamic> data) {
    final raw = data['projects'];
    if (raw == null || raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ProjectAnalysis.fromMap)
        .toList();
  }

  List<String> _parseStringList(Map<String, dynamic> data, String key) {
    final val = data[key];
    if (val == null) return [];
    if (val is List) return val.map((e) => e.toString()).toList();
    if (val is String) return [val];
    return [];
  }

  int _clamp(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt().clamp(0, 100);
    if (value is String) return (int.tryParse(value) ?? 0).clamp(0, 100);
    return 0;
  }
}

// ─── Exception ────────────────────────────────────────────────────────────────

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => 'AiException: $message';
}
