import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:next_hire/core/services/app_config.dart';

// ─── Parsing Helpers ────────────────────────────────────────────────────────

int _score(dynamic value) {
  if (value is num) return value.toInt().clamp(0, 100);
  if (value is String) return int.tryParse(value.trim())?.clamp(0, 100) ?? 0;
  return 0;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return [];
  return value
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();
}

List<InterviewQA> _questionList(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((e) => InterviewQA.fromMap(Map<String, dynamic>.from(e)))
      .where((q) => q.question.isNotEmpty && q.answer.isNotEmpty)
      .toList();
}

// ─── Data Models ──────────────────────────────────────────────────────────────

/// The 7 interview rounds this feature always tries to cover — matches the
/// report's "HR / Technical / Coding / Behavioural / Resume Based / Project
/// Based" sections, plus Scenario-Based questions folded in alongside them.
enum InterviewQuestionCategory {
  hr,
  technical,
  coding,
  scenario,
  behavioural,
  project,
  resumeBased,
}

extension InterviewQuestionCategoryX on InterviewQuestionCategory {
  String get label {
    switch (this) {
      case InterviewQuestionCategory.hr:
        return 'HR';
      case InterviewQuestionCategory.technical:
        return 'Technical';
      case InterviewQuestionCategory.coding:
        return 'Coding';
      case InterviewQuestionCategory.scenario:
        return 'Scenario-Based';
      case InterviewQuestionCategory.behavioural:
        return 'Behavioural';
      case InterviewQuestionCategory.project:
        return 'Project-Based';
      case InterviewQuestionCategory.resumeBased:
        return 'Resume-Based';
    }
  }

  static InterviewQuestionCategory fromString(String? raw) {
    final s = (raw ?? '').toLowerCase();
    if (s.contains('hr')) return InterviewQuestionCategory.hr;
    if (s.contains('cod')) return InterviewQuestionCategory.coding;
    if (s.contains('scenario')) return InterviewQuestionCategory.scenario;
    if (s.contains('behav')) return InterviewQuestionCategory.behavioural;
    if (s.contains('project')) return InterviewQuestionCategory.project;
    if (s.contains('resume')) return InterviewQuestionCategory.resumeBased;
    return InterviewQuestionCategory.technical; // sensible default
  }
}

/// One interview question with its interview-ready model answer.
class InterviewQA {
  final String question;
  final String answer;
  final String difficulty; // Easy | Medium | Hard
  final InterviewQuestionCategory category;

  const InterviewQA({
    required this.question,
    required this.answer,
    required this.difficulty,
    required this.category,
  });

  factory InterviewQA.fromMap(Map<String, dynamic> map) => InterviewQA(
    question: (map['question'] as String? ?? '').trim(),
    answer: (map['answer'] as String? ?? '').trim(),
    difficulty: _normalizeDifficulty(map['difficulty'] as String?),
    category: InterviewQuestionCategoryX.fromString(
      map['category'] as String?,
    ),
  );

  static String _normalizeDifficulty(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.startsWith('easy')) return 'Easy';
    if (s.startsWith('hard')) return 'Hard';
    return 'Medium';
  }

  Map<String, dynamic> toMap() => {
    'question': question,
    'answer': answer,
    'difficulty': difficulty,
    'category': category.label,
  };
}

/// Granular ATS sub-scores shown in the "ATS Report" section.
class InterviewPrepAtsAnalysis {
  final int atsScore;
  final int keywordCoverage;
  final int formatScore;
  final int readabilityScore;

  const InterviewPrepAtsAnalysis({
    required this.atsScore,
    required this.keywordCoverage,
    required this.formatScore,
    required this.readabilityScore,
  });

  factory InterviewPrepAtsAnalysis.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const InterviewPrepAtsAnalysis(
        atsScore: 0,
        keywordCoverage: 0,
        formatScore: 0,
        readabilityScore: 0,
      );
    }
    return InterviewPrepAtsAnalysis(
      atsScore: _score(map['atsScore']),
      keywordCoverage: _score(map['keywordCoverage']),
      formatScore: _score(map['formatScore']),
      readabilityScore: _score(map['readabilityScore']),
    );
  }
}

/// The full Resume ⇄ Job Description fit report. [interviewQuestions] holds
/// 5 entries for the free preview and grows to ~20 once the user unlocks
/// the rest via [InterviewPrepService.unlockRemainingQuestions].
class JobFitReport {
  final int overallScore;
  final String recommendation;
  final String summary;
  final List<String> skillsMatched;
  final List<String> skillsMissing;
  final String experienceMatch;
  final String educationMatch;
  final String projectAnalysis;
  final List<String> strengths;
  final List<String> weaknesses;
  final InterviewPrepAtsAnalysis atsAnalysis;
  final String selectionProbability;
  final List<String> resumeImprovements;
  final List<String> topMissingKeywords;
  final String finalRecruiterAdvice;
  final List<InterviewQA> interviewQuestions;

  const JobFitReport({
    required this.overallScore,
    required this.recommendation,
    required this.summary,
    required this.skillsMatched,
    required this.skillsMissing,
    required this.experienceMatch,
    required this.educationMatch,
    required this.projectAnalysis,
    required this.strengths,
    required this.weaknesses,
    required this.atsAnalysis,
    required this.selectionProbability,
    required this.resumeImprovements,
    required this.topMissingKeywords,
    required this.finalRecruiterAdvice,
    required this.interviewQuestions,
  });

  factory JobFitReport.fromMap(Map<String, dynamic> map) => JobFitReport(
    overallScore: _score(map['overallScore']),
    recommendation: (map['recommendation'] as String? ?? '').trim(),
    summary: (map['summary'] as String? ?? '').trim(),
    skillsMatched: _stringList(map['skillsMatched']),
    skillsMissing: _stringList(map['skillsMissing']),
    experienceMatch: (map['experienceMatch'] as String? ?? '').trim(),
    educationMatch: (map['educationMatch'] as String? ?? '').trim(),
    projectAnalysis: (map['projectAnalysis'] as String? ?? '').trim(),
    strengths: _stringList(map['strengths']),
    weaknesses: _stringList(map['weaknesses']),
    atsAnalysis: InterviewPrepAtsAnalysis.fromMap(
      map['atsAnalysis'] as Map<String, dynamic>?,
    ),
    selectionProbability: (map['selectionProbability'] as String? ?? '')
        .trim(),
    resumeImprovements: _stringList(map['resumeImprovements']),
    topMissingKeywords: _stringList(map['topMissingKeywords']),
    finalRecruiterAdvice: (map['finalRecruiterAdvice'] as String? ?? '')
        .trim(),
    interviewQuestions: _questionList(map['interviewQuestions']),
  );

  /// Copy with [extra] questions appended — used once the paid unlock
  /// returns the remaining questions to add to the free preview's 5.
  JobFitReport withMoreQuestions(List<InterviewQA> extra) => JobFitReport(
    overallScore: overallScore,
    recommendation: recommendation,
    summary: summary,
    skillsMatched: skillsMatched,
    skillsMissing: skillsMissing,
    experienceMatch: experienceMatch,
    educationMatch: educationMatch,
    projectAnalysis: projectAnalysis,
    strengths: strengths,
    weaknesses: weaknesses,
    atsAnalysis: atsAnalysis,
    selectionProbability: selectionProbability,
    resumeImprovements: resumeImprovements,
    topMissingKeywords: topMissingKeywords,
    finalRecruiterAdvice: finalRecruiterAdvice,
    interviewQuestions: [...interviewQuestions, ...extra],
  );

  /// True once more than the free preview's questions have been loaded.
  bool get isFullyUnlocked => interviewQuestions.length > 5;

  String get matchLabel {
    if (overallScore >= 80) return 'Great Match';
    if (overallScore >= 65) return 'Good Match';
    if (overallScore >= 50) return 'Fair Match';
    return 'Needs Work';
  }

  Map<InterviewQuestionCategory, List<InterviewQA>> get questionsByCategory {
    final map = <InterviewQuestionCategory, List<InterviewQA>>{};
    for (final q in interviewQuestions) {
      map.putIfAbsent(q.category, () => []).add(q);
    }
    return map;
  }
}

class InterviewPrepException implements Exception {
  final String message;
  const InterviewPrepException(this.message);
  @override
  String toString() => message;
}

// ─── Service ────────────────────────────────────────────────────────────────

/// Generates the free Resume ⇄ JD fit report (score + analysis + 5 sample
/// interview questions) and, after payment, the remaining ~15 questions.
///
/// Self-contained on purpose — mirrors the pattern in resume_improve_service.dart
/// (its own HTTP call + robust JSON extraction) rather than sharing AiService,
/// which is scoped to the free ATS/job-role-match flows.
class InterviewPrepService {
  static const String _model = 'llama-3.3-70b-versatile';
  static const int _maxResumeChars = 12000;
  static const int _maxJdChars = 6000;
  static const int _totalQuestionTarget = 20;

  static const List<String> _freeCategories = [
    'HR',
    'Technical',
    'Coding',
    'Behavioural',
    'Resume-Based',
  ];
  static const List<String> _allCategories = [
    'HR',
    'Technical',
    'Coding',
    'Scenario-Based',
    'Behavioural',
    'Project-Based',
    'Resume-Based',
  ];

  /// Free tier: full analysis + exactly 5 interview questions.
  Future<JobFitReport> analyzeFit({
    required String resumeText,
    required String jobDescription,
  }) async {
    final resume = resumeText.trim();
    final jd = jobDescription.trim();

    if (resume.length < 80) {
      throw const InterviewPrepException(
        'That resume looks too short to analyse — please provide a fuller version.',
      );
    }
    if (jd.length < 50) {
      throw const InterviewPrepException(
        'Please paste a more complete job description (at least a few lines).',
      );
    }

    return _callAndProcessWithRetry(
      prompt: _buildFreeReportPrompt(
        resumeText: _safeText(resume, _maxResumeChars),
        jobDescription: _safeText(jd, _maxJdChars),
      ),
      maxTokens: 3200,
      temperature: 0.3,
      process: (raw) {
        final report = JobFitReport.fromMap(_decode(raw));
        if (report.interviewQuestions.isEmpty) {
          throw const FormatException('No interview questions were returned.');
        }
        return report;
      },
    );
  }

  /// Paid unlock: the remaining questions (up to a total of 20), guaranteed
  /// not to repeat anything in [alreadyAsked].
  Future<List<InterviewQA>> unlockRemainingQuestions({
    required String resumeText,
    required String jobDescription,
    required List<InterviewQA> alreadyAsked,
  }) async {
    final remaining = (_totalQuestionTarget - alreadyAsked.length).clamp(
      1,
      _totalQuestionTarget,
    );

    return _callAndProcessWithRetry(
      prompt: _buildRemainingQuestionsPrompt(
        resumeText: _safeText(resumeText.trim(), _maxResumeChars),
        jobDescription: _safeText(jobDescription.trim(), _maxJdChars),
        alreadyAsked: alreadyAsked,
        remainingCount: remaining,
      ),
      maxTokens: 4096,
      temperature: 0.35,
      process: (raw) {
        final list = _questionList(_decode(raw)['interviewQuestions']);
        if (list.isEmpty) {
          throw const FormatException('No new interview questions were returned.');
        }
        return list;
      },
    );
  }

  // ── Prompt builders ──────────────────────────────────────────────────────

  String _buildFreeReportPrompt({
    required String resumeText,
    required String jobDescription,
  }) {
    return '''
You are an expert ATS Resume Reviewer, Technical Recruiter, HR Manager, Career Coach, and Interview Specialist.

Analyse the RESUME against the JOB DESCRIPTION below and produce a professional, realistic hiring analysis. Do not inflate scores — an average resume should score in the 50-70 range; only a genuinely strong match should score 80+.

=========================
RESUME
=========================
$resumeText

=========================
JOB DESCRIPTION
=========================
$jobDescription

=========================
RULES
=========================
1. Compare every requirement in the Job Description against the Resume.
2. "overallScore" and "atsAnalysis.atsScore" must be realistic integers 0-100.
3. "skillsMatched" — every skill the JD asks for that is genuinely present in the resume.
4. "skillsMissing" — every important skill the JD asks for that the resume does not show.
5. "experienceMatch" — 1-2 sentences on how relevant the candidate's experience is to this role.
6. "projectAnalysis" — 1-2 sentences on whether the candidate's projects are relevant to this role.
7. "educationMatch" — 1 sentence on whether education meets the requirement.
8. "selectionProbability" — a short verdict (e.g. "High", "Moderate", "Low") plus a brief reason.
9. "recommendation" is a one-line verdict; "summary" explains WHY in 2-3 sentences.
10. "resumeImprovements" — 3 to 5 specific, actionable changes that would meaningfully raise this candidate's chances for THIS job.
11. "topMissingKeywords" — the 3-8 highest-impact keywords from the JD that are absent from the resume.
12. Generate EXACTLY 5 interview questions, one from each category in this order: ${_freeCategories.join(', ')}.
13. Each question needs a detailed, interview-ready model "answer" written in first person as the candidate, using ONLY achievements, tools and experience that actually appear in the resume.
14. "difficulty" is exactly one of "Easy", "Medium", "Hard". "category" is exactly one of: ${_freeCategories.join(', ')}.
15. "finalRecruiterAdvice" — 2-3 sentences of closing advice from a recruiter's point of view for this specific candidate and role.
16. Never invent technologies, employers, titles or achievements absent from both documents.
17. Base every judgement strictly on the Resume and Job Description above — nothing else.
18. Return ONLY the JSON object below. No markdown fences, no commentary before or after it.

=========================
OUTPUT FORMAT
=========================
{
  "overallScore": 0,
  "recommendation": "",
  "summary": "",
  "skillsMatched": [],
  "skillsMissing": [],
  "experienceMatch": "",
  "educationMatch": "",
  "projectAnalysis": "",
  "strengths": [],
  "weaknesses": [],
  "atsAnalysis": {
    "atsScore": 0,
    "keywordCoverage": 0,
    "formatScore": 0,
    "readabilityScore": 0
  },
  "selectionProbability": "",
  "resumeImprovements": ["", "", ""],
  "topMissingKeywords": ["", ""],
  "finalRecruiterAdvice": "",
  "interviewQuestions": [
    { "question": "", "answer": "", "difficulty": "Easy", "category": "HR" }
  ]
}
''';
  }

  String _buildRemainingQuestionsPrompt({
    required String resumeText,
    required String jobDescription,
    required List<InterviewQA> alreadyAsked,
    required int remainingCount,
  }) {
    final askedList = alreadyAsked
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. [${e.value.category.label}] ${e.value.question}')
        .join('\n');

    return '''
You are an expert Technical Recruiter and Interview Coach preparing a candidate for a real interview for this role.

You already gave the candidate these ${alreadyAsked.length} interview questions — do NOT repeat them or ask close variants of them:
$askedList

=========================
RESUME
=========================
$resumeText

=========================
JOB DESCRIPTION
=========================
$jobDescription

=========================
TASK
=========================
Generate exactly $remainingCount NEW interview questions with detailed model answers so that, combined with the ${alreadyAsked.length} above, the full set gives solid coverage across all of these rounds: ${_allCategories.join(', ')}.

Rules:
1. Do not repeat or closely rephrase any question listed above.
2. Never invent technologies, employers, titles or achievements absent from the Resume or Job Description.
3. Each "answer" must be interview-ready — specific, professional, 3-6 sentences, written in first person as the candidate, using only what's actually in the resume.
4. "difficulty" is exactly one of "Easy", "Medium", "Hard".
5. "category" is exactly one of: ${_allCategories.join(', ')}.
6. Spread the $remainingCount questions reasonably evenly across those categories.
7. Return ONLY the JSON object below — no markdown fences, no commentary.

=========================
OUTPUT FORMAT
=========================
{
  "interviewQuestions": [
    { "question": "", "answer": "", "difficulty": "Medium", "category": "Technical" }
  ]
}
''';
  }

  // ── Text safety ──────────────────────────────────────────────────────────

  /// Truncates [text] to [maxChars] at a word boundary and notes the clip.
  String _safeText(String text, int maxChars) {
    final trimmed = text.trim();
    if (trimmed.length <= maxChars) return trimmed;
    int cutAt = maxChars;
    while (cutAt > 0 && trimmed[cutAt] != ' ' && trimmed[cutAt] != '\n') {
      cutAt--;
    }
    return '${trimmed.substring(0, cutAt)}\n\n[Text truncated to fit context window — end omitted]';
  }

  // ── HTTP + retry (mirrors resume_improve_service.dart) ────────────────────

  Future<String> _call(
    String prompt, {
    required int maxTokens,
    double? temperature,
  }) async {
    final backendUrl = AppConfig.backendUrl;
    if (backendUrl.isEmpty) {
      throw const InterviewPrepException(
        'Backend URL not configured. Pass --dart-define=BACKEND_URL=...',
      );
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$backendUrl/api/ai/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'prompt': prompt,
              'model': _model,
              'maxTokens': maxTokens,
              if (temperature != null) 'temperature': temperature,
            }),
          )
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () => throw const InterviewPrepException(
              'Request timed out. Please try again.',
            ),
          );
    } on InterviewPrepException {
      rethrow;
    } catch (_) {
      throw const InterviewPrepException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode != 200) {
      String message = 'AI service error ${response.statusCode}';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['error']?.toString() ?? message;
      } catch (_) {
        // response body wasn't JSON — keep the generic message
      }
      throw InterviewPrepException(message);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw InterviewPrepException(
        data['error']?.toString() ?? 'AI service error',
      );
    }
    return data['content'] as String? ?? '';
  }

  /// Calls the model and decodes+post-processes its response, retrying the
  /// FULL round-trip if [process] throws — usually a one-off formatting
  /// slip that a fresh generation attempt doesn't repeat.
  Future<T> _callAndProcessWithRetry<T>({
    required String prompt,
    required int maxTokens,
    required T Function(String rawResponse) process,
    double? temperature,
    int maxAttempts = 2,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final raw = await _call(
        prompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );
      try {
        return process(raw);
      } catch (e) {
        if (attempt >= maxAttempts) {
          if (e is InterviewPrepException) rethrow;
          throw const InterviewPrepException(
            'The AI response could not be understood. Please try again.',
          );
        }
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    throw const InterviewPrepException(
      'Request failed after retries. Please try again.',
    );
  }

  // ── Robust JSON extraction (mirrors resume_improve_service.dart) ──────────

  Map<String, dynamic> _decode(String raw) {
    String clean = raw
        .replaceAll('```json', '')
        .replaceAll('```dart', '')
        .replaceAll('```', '')
        .trim();

    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      clean = clean.substring(start, end + 1);
    }

    clean = _sanitizeJsonControlChars(clean);

    try {
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      clean = clean
          .replaceAll(RegExp(r',\s*}'), '}')
          .replaceAll(RegExp(r',\s*\]'), ']');
      try {
        return jsonDecode(clean) as Map<String, dynamic>;
      } catch (e2) {
        throw FormatException('AI returned invalid JSON: $e2');
      }
    }
  }

  String _sanitizeJsonControlChars(String json) {
    final buf = StringBuffer();
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < json.length; i++) {
      final ch = json[i];
      final code = ch.codeUnitAt(0);

      if (escaped) {
        buf.write(ch);
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        buf.write(ch);
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        buf.write(ch);
        continue;
      }
      if (inString) {
        if (code == 0x0A) {
          buf.write('\\n');
          continue;
        }
        if (code == 0x0D) {
          buf.write('\\r');
          continue;
        }
        if (code == 0x09) {
          buf.write('\\t');
          continue;
        }
        if (code < 0x20) continue;
      }
      buf.write(ch);
    }
    return buf.toString();
  }
}
