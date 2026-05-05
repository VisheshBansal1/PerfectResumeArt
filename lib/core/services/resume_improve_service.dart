import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Holds the fully improved resume with before/after data
class ImprovedResume {
  final String originalText;
  final String improvedText;
  final String improvedSummary;
  final List<Map<String, String>> bulletChanges; // [{original, improved}]
  final List<String> impactAdded;

  const ImprovedResume({
    required this.originalText,
    required this.improvedText,
    required this.improvedSummary,
    required this.bulletChanges,
    required this.impactAdded,
  });

  factory ImprovedResume.fromMap(Map<String, dynamic> map, String original) {
    final bullets = (map['bulletChanges'] as List? ?? [])
        .whereType<Map>()
        .map((e) => {
              'original': e['original']?.toString() ?? '',
              'improved': e['improved']?.toString() ?? '',
            })
        .toList();
    return ImprovedResume(
      originalText: original,
      improvedText: map['improvedText'] as String? ?? original,
      improvedSummary: map['improvedSummary'] as String? ?? '',
      bulletChanges: bullets,
      impactAdded: _strList(map, 'impactAdded'),
    );
  }

  static List<String> _strList(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

/// JD optimization result
class JdOptimizedResume {
  final String originalText;
  final String optimizedText;
  final List<String> keywordsAdded;
  final List<String> linesChanged;
  final int estimatedAtsBoost;

  const JdOptimizedResume({
    required this.originalText,
    required this.optimizedText,
    required this.keywordsAdded,
    required this.linesChanged,
    required this.estimatedAtsBoost,
  });

  factory JdOptimizedResume.fromMap(Map<String, dynamic> map, String original) =>
      JdOptimizedResume(
        originalText: original,
        optimizedText: map['optimizedText'] as String? ?? original,
        keywordsAdded: _strList(map, 'keywordsAdded'),
        linesChanged: _strList(map, 'linesChanged'),
        estimatedAtsBoost:
            (map['estimatedAtsBoost'] as num?)?.toInt().clamp(0, 100) ?? 0,
      );

  static List<String> _strList(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

/// Why-you-get-rejected result
class RejectionReason {
  final String category; // e.g. "Impact", "Metrics", "Summary"
  final String verdict; // brutal one-liner
  final String fix; // specific fix
  final String severity; // "critical" | "high" | "medium"

  const RejectionReason({
    required this.category,
    required this.verdict,
    required this.fix,
    required this.severity,
  });

  factory RejectionReason.fromMap(Map<String, dynamic> m) => RejectionReason(
        category: m['category'] as String? ?? '',
        verdict: m['verdict'] as String? ?? '',
        fix: m['fix'] as String? ?? '',
        severity: m['severity'] as String? ?? 'medium',
      );
}

/// Project improvement result
class ImprovedProject {
  final String original;
  final String improved;
  final List<String> tipsApplied;

  const ImprovedProject({
    required this.original,
    required this.improved,
    required this.tipsApplied,
  });
}

/// "Add these to get selected" result
class SelectionBooster {
  final List<String> projectsToAdd;
  final List<String> skillsToAdd;
  final List<String> metricsToAdd;
  final List<String> keywordsToAdd;
  final String priorityAction;

  const SelectionBooster({
    required this.projectsToAdd,
    required this.skillsToAdd,
    required this.metricsToAdd,
    required this.keywordsToAdd,
    required this.priorityAction,
  });

  factory SelectionBooster.fromMap(Map<String, dynamic> m) => SelectionBooster(
        projectsToAdd: _strList(m, 'projectsToAdd'),
        skillsToAdd: _strList(m, 'skillsToAdd'),
        metricsToAdd: _strList(m, 'metricsToAdd'),
        keywordsToAdd: _strList(m, 'keywordsToAdd'),
        priorityAction: m['priorityAction'] as String? ?? '',
      );

  static List<String> _strList(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

// ─── Service ───────────────────────────────────────────────────────────────────
class ResumeImproveService {
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  // ── 1. Fix My Resume — full rewrite ────────────────────────────────────────
  Future<ImprovedResume> fixResume({
    required String resumeText,
    String jobTitle = '',
  }) async {
    final prompt = '''
You are a world-class resume writer who has helped 50,000+ candidates land jobs at FAANG, startups, and top Indian tech companies.
Your job: Transform this resume into the best version of itself.

${jobTitle.isNotEmpty ? 'Target Role: $jobTitle\n' : ''}

TRANSFORMATION RULES:
1. SUMMARY REWRITE: Make it a 2-3 line punchy professional summary with role + experience + top skill + impact hint.
2. BULLET REWRITE: Every weak bullet → start with power action verb + specific tech + quantified impact (estimate with ~ if unknown).
   - Weak: "Worked on backend" → Strong: "Engineered REST APIs serving ~5,000 daily requests using Node.js + PostgreSQL"
   - Weak: "Made flutter app" → Strong: "Built Flutter e-commerce app with Firebase Auth, Firestore, reducing checkout time by ~40%"
3. IMPACT ADD: Add measurable outcomes where missing (use ~ for estimates).
4. Keep ALL original content — only upgrade the language and structure.
5. Do NOT add fake companies, fake degrees, or fake projects.

ORIGINAL RESUME:
$resumeText

Respond ONLY as valid JSON, no markdown, no explanation:
{
  "improvedText": "<full rewritten resume as plain text>",
  "improvedSummary": "<the new 2-3 line summary only>",
  "bulletChanges": [
    {"original": "<exact original bullet>", "improved": "<your rewrite>"},
    {"original": "<exact original bullet>", "improved": "<your rewrite>"}
  ],
  "impactAdded": ["<specific impact/metric added or estimated>", ...]
}
''';

    final raw = await _call(prompt, maxTokens: 4096);
    final data = _decode(raw);
    return ImprovedResume.fromMap(data, resumeText);
  }

  // ── 2. JD Auto Optimization ────────────────────────────────────────────────
  Future<JdOptimizedResume> optimizeWithJD({
    required String resumeText,
    required String jobDescription,
  }) async {
    final prompt = '''
You are an expert ATS consultant. Your job: optimize this resume to maximally match the given Job Description.

RULES:
1. Extract all important keywords, skills, and phrases from the JD.
2. Naturally embed missing keywords into existing bullet points (don't add fake experience).
3. Rephrase existing bullets to mirror JD language where semantically equivalent.
4. Add any missing but truthfully inferable skills to the Skills section.
5. Adjust Summary/Objective to directly echo the JD's requirements.
6. Do NOT fabricate roles, projects, or companies.

JOB DESCRIPTION:
$jobDescription

RESUME:
$resumeText

Respond ONLY as valid JSON:
{
  "optimizedText": "<full optimized resume as plain text>",
  "keywordsAdded": ["keyword1", "keyword2", ...],
  "linesChanged": ["BEFORE: ... → AFTER: ...", ...],
  "estimatedAtsBoost": <integer 0-100 — expected ATS score increase>
}
''';

    final raw = await _call(prompt, maxTokens: 4096);
    final data = _decode(raw);
    return JdOptimizedResume.fromMap(data, resumeText);
  }

  // ── 3. Why You Get Rejected ─────────────────────────────────────────────────
  Future<List<RejectionReason>> getWhyRejected({
    required String resumeText,
    String jobTitle = '',
  }) async {
    final prompt = '''
You are a brutally honest technical recruiter. Your job: tell this candidate EXACTLY why they are getting rejected.
No encouragement. No padding. Just brutal, actionable truth.
${jobTitle.isNotEmpty ? 'Context: they are applying for $jobTitle roles.\n' : ''}

Analyze these dimensions:
- METRICS: Do bullets have numbers/impact? Are they generic?
- SUMMARY: Is it specific or a generic paragraph?
- PROJECTS: Are projects impressive or basic to-do app clones?
- ATS: Will standard ATS systems parse and rank this well?
- FIRST_IMPRESSION: What does a recruiter think in first 6 seconds?
- SKILLS_PROOF: Are skills only listed or also demonstrated in projects?

RESUME:
$resumeText

Return ONLY valid JSON:
{
  "reasons": [
    {
      "category": "Metrics",
      "verdict": "<harsh 1-line verdict>",
      "fix": "<specific actionable fix>",
      "severity": "critical"
    },
    {
      "category": "Summary",
      "verdict": "<harsh 1-line verdict>",
      "fix": "<specific actionable fix>",
      "severity": "high"
    }
  ]
}

Severity must be: "critical", "high", or "medium". Include 4-7 reasons.
''';

    final raw = await _call(prompt, maxTokens: 1500);
    final data = _decode(raw);
    final list = data['reasons'] as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(RejectionReason.fromMap).toList();
  }

  // ── 4. Project Improver ────────────────────────────────────────────────────
  Future<ImprovedProject> improveProjectLine({
    required String projectLine,
    String context = '',
  }) async {
    final prompt = '''
You are an expert resume writer. Transform this weak project description into an impressive one for a tech resume.

RULES:
- Start with a strong action verb (Built, Developed, Engineered, Designed, Architected)
- Include tech stack used
- Add measurable impact or scale (users, performance, downloads — estimate with ~ if unknown)
- Maximum 2 sentences or 30 words
- Sound impressive but believable

Original: "$projectLine"
${context.isNotEmpty ? 'Context: $context' : ''}

Return ONLY valid JSON:
{
  "improved": "<improved project line>",
  "tipsApplied": ["tip1", "tip2", "tip3"]
}
''';

    final raw = await _call(prompt, maxTokens: 512);
    final data = _decode(raw);
    return ImprovedProject(
      original: projectLine,
      improved: data['improved'] as String? ?? projectLine,
      tipsApplied: (data['tipsApplied'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  // ── 5. "Add These to Get Selected" ────────────────────────────────────────
  Future<SelectionBooster> getSelectionBoosters({
    required String resumeText,
    String jobTitle = '',
  }) async {
    final prompt = '''
You are a hiring manager. Based on this resume, tell the candidate EXACTLY what to add to significantly increase their chances of getting selected.
${jobTitle.isNotEmpty ? 'They are applying for: $jobTitle\n' : ''}

Be specific. Not generic advice like "add metrics" — give examples like "Add: Reduced API latency from 800ms to 120ms using Redis caching".

RESUME:
$resumeText

Return ONLY valid JSON:
{
  "projectsToAdd": [
    "Build a <specific project type> demonstrating <specific skill> — reason: <why it helps>"
  ],
  "skillsToAdd": [
    "<specific skill/tool> — used in <context> — easy to learn in 1 week"
  ],
  "metricsToAdd": [
    "Add to <project name>: <specific metric example like '~500 daily active users' or '40% faster load time'>"
  ],
  "keywordsToAdd": [
    "<exact keyword to add> — where: <section to add it in>"
  ],
  "priorityAction": "<single most important action to take this week>"
}

Include 2-3 items per category. Be specific and actionable.
''';

    final raw = await _call(prompt, maxTokens: 1500);
    final data = _decode(raw);
    return SelectionBooster.fromMap(data);
  }

  // ── 6. Bundle: Fix + JD Optimize in one call ──────────────────────────────
  Future<Map<String, dynamic>> fullBundleUpgrade({
    required String resumeText,
    required String jobDescription,
    String jobTitle = '',
  }) async {
    final improved = await fixResume(resumeText: resumeText, jobTitle: jobTitle);
    final optimized = await optimizeWithJD(
      resumeText: improved.improvedText,
      jobDescription: jobDescription,
    );
    return {
      'improved': improved,
      'optimized': optimized,
      'finalText': optimized.optimizedText,
    };
  }

  // ── Internal helpers ───────────────────────────────────────────────────────
  Future<String> _call(String prompt, {required int maxTokens}) async {
    if (_apiKey.isEmpty) throw Exception('GROQ_API_KEY not set in .env');

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.15,
            'max_tokens': maxTokens,
            'stream': false,
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception('Groq API error ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['choices']?[0]?['message']?['content'] as String? ?? '';
  }

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
    try {
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      clean = clean
          .replaceAll(RegExp(r',\s*}'), '}')
          .replaceAll(RegExp(r',\s*\]'), ']');
      return jsonDecode(clean) as Map<String, dynamic>;
    }
  }
}
