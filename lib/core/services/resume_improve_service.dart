import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:next_hire/core/services/app_config.dart';

/// Holds the fully improved resume with before/after data + ATS scores
class ImprovedResume {
  final String originalText;
  final String improvedText;
  final String improvedSummary;
  final List<Map<String, String>>
  bulletChanges; // [{original, improved, reason}]
  final List<String> impactAdded;
  final int atsScoreBefore;
  final int atsScoreAfter;
  final List<String> sectionsImproved;
  final List<ActionableSuggestion> actionableSuggestions; // Real things to do

  const ImprovedResume({
    required this.originalText,
    required this.improvedText,
    required this.improvedSummary,
    required this.bulletChanges,
    required this.impactAdded,
    required this.atsScoreBefore,
    required this.atsScoreAfter,
    required this.sectionsImproved,
    this.actionableSuggestions = const [],
  });

  int get atsImprovement => atsScoreAfter - atsScoreBefore;

  factory ImprovedResume.fromMap(Map<String, dynamic> map, String original) {
    final bullets = (map['bulletChanges'] as List? ?? [])
        .whereType<Map>()
        .map(
          (e) => {
            'original': e['original']?.toString() ?? '',
            'improved': e['improved']?.toString() ?? '',
            'reason': e['reason']?.toString() ?? '',
          },
        )
        .toList();
    return ImprovedResume(
      originalText: original,
      improvedText: map['improvedText'] as String? ?? original,
      improvedSummary: map['improvedSummary'] as String? ?? '',
      bulletChanges: bullets,
      impactAdded: _strList(map, 'impactAdded'),
      atsScoreBefore:
          (map['atsScoreBefore'] as num?)?.toInt().clamp(0, 100) ?? 40,
      atsScoreAfter:
          (map['atsScoreAfter'] as num?)?.toInt().clamp(0, 100) ?? 75,
      sectionsImproved: _strList(map, 'sectionsImproved'),
      actionableSuggestions: (map['actionableSuggestions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ActionableSuggestion.fromMap)
          .toList(),
    );
  }

  static List<String> _strList(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

/// Real actionable suggestion — things the user can actually do
class ActionableSuggestion {
  final String
  type; // 'add_link' | 'learn_skill' | 'add_project' | 'certification' | 'structure'
  final String suggestion; // The actual advice
  final String priority; // 'high' | 'medium' | 'low'

  const ActionableSuggestion({
    required this.type,
    required this.suggestion,
    required this.priority,
  });

  factory ActionableSuggestion.fromMap(Map<String, dynamic> m) =>
      ActionableSuggestion(
        type: m['type'] as String? ?? 'general',
        suggestion: m['suggestion'] as String? ?? '',
        priority: m['priority'] as String? ?? 'medium',
      );

  String get emoji {
    switch (type) {
      case 'add_link':
        return '🔗';
      case 'learn_skill':
        return '📚';
      case 'add_project':
        return '🛠️';
      case 'certification':
        return '🏆';
      case 'structure':
        return '📋';
      default:
        return '💡';
    }
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

  factory JdOptimizedResume.fromMap(
    Map<String, dynamic> map,
    String original,
  ) => JdOptimizedResume(
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

// ─── Generated Resume ─────────────────────────────────────────────────────────

class GeneratedResume {
  final String resumeText;
  final String summary;
  final int atsScore;
  final List<String> keyStrengths;
  final List<String> suggestedRoles;
  final List<String> topKeywords;
  final String linkedinSummary;
  final List<String> improvementTips;

  const GeneratedResume({
    required this.resumeText,
    required this.summary,
    required this.atsScore,
    required this.keyStrengths,
    required this.suggestedRoles,
    required this.topKeywords,
    required this.linkedinSummary,
    this.improvementTips = const [],
  });

  factory GeneratedResume.fromMap(Map<String, dynamic> m) => GeneratedResume(
    resumeText: m['resumeText'] as String? ?? '',
    summary: m['summary'] as String? ?? '',
    atsScore: (m['atsScore'] as num?)?.toInt().clamp(0, 100) ?? 70,
    keyStrengths: _strList(m, 'keyStrengths'),
    suggestedRoles: _strList(m, 'suggestedRoles'),
    topKeywords: _strList(m, 'topKeywords'),
    linkedinSummary: m['linkedinSummary'] as String? ?? '',
    improvementTips: _strList(m, 'improvementTips'),
  );

  static List<String> _strList(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

// ─── Generator input models ───────────────────────────────────────────────────

class ExperienceEntry {
  final String company;
  final String role;
  final String duration;
  final String responsibilities;

  const ExperienceEntry({
    required this.company,
    required this.role,
    required this.duration,
    required this.responsibilities,
  });

  String toText() => "$role at $company ($duration):\n$responsibilities";
}

class ProjectEntry {
  final String name;
  final String techStack;
  final String description;

  const ProjectEntry({
    required this.name,
    required this.techStack,
    required this.description,
  });

  String toText() => "$name | $techStack\n$description";
}

// ─── Service ───────────────────────────────────────────────────────────────────
class ResumeImproveService {
  // GROQ_API_KEY removed — AI calls proxy through backend.
  // See AiService._callGroq() which posts to AppConfig.backendUrl/api/ai/chat
  // Calls backend proxy → backend calls Groq with server-side API key
  static const String _model = 'llama-3.3-70b-versatile';

  // ── 1. Fix My Resume — full rewrite ────────────────────────────────────────
  Future<ImprovedResume> fixResume({
    required String resumeText,
    String jobTitle = '',
  }) async {
    final prompt =
        '''
You are an expert resume editor. Improve this resume based ONLY on what is actually there.
No fabricated metrics. No invented projects. Only honest improvements.

${jobTitle.isNotEmpty ? 'Target Role: $jobTitle\n' : ''}

EDITING RULES (follow strictly):
1. SUMMARY: Rewrite to be specific — use the person's actual role, skills, and experience shown in the resume.
2. BULLETS: Make each clearer and stronger WITHOUT inventing numbers.
   - Start with a strong action verb (Built, Developed, Designed, Led, Optimized, Implemented)
   - Name the specific technology used ("using Node.js" not just "using a backend technology")
   - If a real metric EXISTS in the resume: keep it. If not: DO NOT add a fake ~number.
   - "Worked on backend" → "Developed RESTful APIs using Node.js and PostgreSQL" (no fake metric)
   - "Made Flutter app" → "Built a Flutter mobile application with Firebase authentication and Firestore database"
3. STRUCTURE: Ensure standard ATS headers: Professional Summary | Work Experience | Education | Technical Skills | Projects
4. Keep ALL original content — do not remove any information.
5. Do NOT add fake companies, degrees, projects, or metrics.

STEP 1: Score the ORIGINAL resume ATS compatibility (0-100).
STEP 2: Rewrite following the rules above.
STEP 3: Score the IMPROVED resume (must be higher than original).
STEP 4: Generate ACTIONABLE SUGGESTIONS — real specific things this person should do.

For actionable suggestions, analyze what's missing and give honest advice:
- No GitHub/portfolio link → suggest adding it specifically
- No project links → suggest deploying their existing projects  
- Vague project descriptions → tell them what to add (tech stack, what problem it solves)
- Missing certifications → recommend free ones relevant to their specific tech stack
- Thin skills section → suggest specific skills to learn based on what they already know
- No metrics anywhere → explain HOW to get real metrics (track downloads, measure performance, etc.)

RESUME:
$resumeText

Return ONLY valid JSON:
{
  "improvedText": "<complete improved resume — all sections — plain text>",
  "improvedSummary": "<2-3 line summary based on their actual experience>",
  "atsScoreBefore": <0-100>,
  "atsScoreAfter":  <0-100, must be higher>,
  "sectionsImproved": ["<names of sections changed>"],
  "bulletChanges": [
    {
      "original": "<exact original line>",
      "improved": "<honest rewrite — no fake metrics>",
      "reason":   "<what was improved: e.g. Added action verb, Named specific tech, Clarified outcome>"
    }
  ],
  "impactAdded": ["<only real metrics that were ALREADY in resume and preserved>"],
  "actionableSuggestions": [
    {
      "type": "add_link",
      "suggestion": "<specific advice for THIS resume>",
      "priority": "high"
    }
  ]
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
    final prompt =
        '''
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
    final prompt =
        '''
You are a senior technical recruiter who has reviewed 10,000+ resumes.
Analyze THIS specific resume honestly. Reference their actual content in your feedback.

${jobTitle.isNotEmpty ? 'Role: applying for $jobTitle.\n' : ''}

Analyze these areas based on what is ACTUALLY in the resume:
- ACTION_VERBS: Do bullets start with strong verbs or are they passive?
- SPECIFICITY: Are technologies named specifically or vague?
- METRICS: Does the resume have real numbers anywhere?
- SUMMARY: Does a summary exist? Is it role-specific?
- PROJECTS: Described with tech stack and outcome? Or just project names?
- ATS_STRUCTURE: Standard section headers? Field-relevant keywords?
- FIRST_IMPRESSION: What stands out (or doesn't) in the first 6 seconds?
- COMPLETENESS: Missing contact info, GitHub, or key sections?

RESUME:
$resumeText

For EACH issue: reference their actual content, give a specific fix that applies to THIS resume.

Return ONLY valid JSON:
{
  "reasons": [
    {
      "category": "<dimension>",
      "verdict": "<honest verdict referencing their specific resume content>",
      "fix": "<actionable fix specific to their resume — not generic advice>",
      "severity": "critical"
    }
  ]
}

Severity: "critical" (auto-rejected), "high" (lowers ranking), "medium" (minor gap).
Include 5-7 reasons. Be specific to THIS resume.
''';

    final raw = await _call(prompt, maxTokens: 1500);
    final data = _decode(raw);
    final list = data['reasons'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(RejectionReason.fromMap)
        .toList();
  }

  // ── 4. Project Improver ────────────────────────────────────────────────────
  Future<ImprovedProject> improveProjectLine({
    required String projectLine,
    String context = '',
  }) async {
    final prompt =
        '''
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
      tipsApplied: (data['tipsApplied'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  // ── 5. "Add These to Get Selected" ────────────────────────────────────────
  // ── 5. Selection Booster ──────────────────────────────────────────────────
  Future<SelectionBooster> getSelectionBoosters({
    required String resumeText,
    String jobTitle = '',
  }) async {
    final targetRole = jobTitle.isNotEmpty ? jobTitle : 'software developer';
    final prompt =
        '''
You are a senior tech recruiter who has reviewed 10,000+ resumes. Analyze this SPECIFIC resume and tell the candidate what to add to get more interviews.

Target Role: $targetRole

CANDIDATE RESUME:
$resumeText

STRICT RULES — violating these makes your response useless:
1. Reference ACTUAL project names, company names from the resume above.
2. Metric suggestions must name a REAL project from the resume (not a placeholder).
3. Skill suggestions must logically extend their EXISTING tech stack.
4. Project suggestions must be buildable using their current skills.
5. NEVER give generic advice that could apply to anyone — be specific to THIS resume.

Return ONLY valid JSON (no markdown):
{
  "priorityAction": "<the single most impactful action this week, referencing something from their resume>",
  "projectsToAdd": [
    "<project using their exact stack> — reason: <why this helps their specific profile>",
    "<project using their exact stack> — reason: <why this helps their specific profile>",
    "<project using their exact stack> — reason: <why this helps their specific profile>"
  ],
  "skillsToAdd": [
    "<skill that directly extends what they already know> — complements their <specific skill> — learn in <time>",
    "<skill that directly extends what they already know> — complements their <specific skill> — learn in <time>",
    "<skill that directly extends what they already know> — complements their <specific skill> — learn in <time>"
  ],
  "metricsToAdd": [
    "Add to <EXACT project name from resume>: <concrete metric like ~2,000 daily users or 45% faster>",
    "Add to <EXACT project name from resume>: <concrete metric>",
    "Add to <EXACT project name from resume>: <concrete metric>"
  ],
  "keywordsToAdd": [
    "<exact keyword missing from resume> — add to: <section name>",
    "<exact keyword missing from resume> — add to: <section name>",
    "<exact keyword missing from resume> — add to: <section name>"
  ]
}
''';

    final raw = await _call(prompt, maxTokens: 1800);
    final data = _decode(raw);
    return SelectionBooster.fromMap(data);
  }

  // ── 6. Bundle: Fix + JD Optimize in one call ──────────────────────────────
  Future<Map<String, dynamic>> fullBundleUpgrade({
    required String resumeText,
    required String jobDescription,
    String jobTitle = '',
  }) async {
    final improved = await fixResume(
      resumeText: resumeText,
      jobTitle: jobTitle,
    );
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

  // ── 7. AI Resume Generator ────────────────────────────────────────────────
  Future<GeneratedResume> generateResume({
    required String fullName,
    required String email,
    required String phone,
    required String location,
    required String targetRole,
    required String yearsExp,
    required List<ExperienceEntry> experiences,
    required String education,
    required String skills,
    required List<ProjectEntry> projects,
    String existingResumeText =
        '', // NEW: pass raw resume PDF text for deep extraction
  }) async {
    final expText = experiences.isEmpty
        ? 'No experience listed — treat as fresher'
        : experiences.map((e) => e.toText()).join('\n\n');

    final projText = projects.isEmpty
        ? 'No projects listed'
        : projects.map((p) => p.toText()).join('\n\n');

    final hasExisting = existingResumeText.trim().isNotEmpty;
    final existingBlock = hasExisting
        ? '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CANDIDATE'S EXISTING RESUME (extract ALL real data — companies, colleges, projects, metrics, dates, skills):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$existingResumeText
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INSTRUCTION: Extract every real detail from the resume above (actual company names, actual job titles, actual dates, actual universities, actual GPA/CGPA, actual project names, actual technologies). Use the form data below only for anything missing from the existing resume.
'''
        : '';

    final prompt =
        '''
You are a world-class professional resume writer with 15+ years of experience helping candidates at FAANG companies and top startups. You have written resumes that achieve 90%+ ATS pass rates. Your task: produce an OUTSTANDING, interview-winning resume.

$existingBlock

CANDIDATE DETAILS (use to fill any gaps not found in existing resume):
Name: $fullName
Email: $email | Phone: $phone | Location: $location
Target Role: $targetRole
Years of Experience: $yearsExp

ADDITIONAL EXPERIENCE PROVIDED:
$expText

EDUCATION PROVIDED:
$education

SKILLS PROVIDED: $skills

ADDITIONAL PROJECTS:
$projText

━━ STRICT WRITING RULES — EVERY RULE IS MANDATORY ━━

PROFESSIONAL SUMMARY (3 lines):
• Line 1: "[X] years of experience as [specific role] specializing in [key tech stack]"
• Line 2: Mention 2 measurable achievements (use real numbers from resume, estimate with ~)
• Line 3: "Seeking [targetRole] to [specific value you bring]"

EXPERIENCE BULLETS (MOST IMPORTANT):
• Formula: [Strong Action Verb] + [specific what] + [technology used] + [quantified result]
• EVERY bullet needs a metric. If not in resume, ESTIMATE with ~ (e.g., ~30% faster, ~5,000 users)
• Power verbs: Architected, Engineered, Spearheaded, Optimized, Automated, Delivered, Reduced, Increased, Launched, Mentored
• BAD: "Worked on backend APIs" 
• GOOD: "Engineered 12 RESTful APIs using Node.js and PostgreSQL, reducing average response time by ~40% and supporting ~8,000 daily active users"
• Minimum 3 bullets per job. Maximum 5 bullets per job.

SKILLS SECTION:
• Group by: Programming Languages | Frontend | Backend | Databases | Cloud/DevOps | Tools & Frameworks
• Include ONLY skills that appear in resume OR in the provided skills list

PROJECTS (make them shine):
• Line 1: "Built [project name] — [what it does] using [tech stack]"
• Line 2: "[Key achievement or metric] | [GitHub/deployment link if mentioned]"

EDUCATION:
• Include actual CGPA/GPA if found in resume
• Add relevant coursework if found

ATS OPTIMIZATION:
• Use exact keywords recruiters search for "$targetRole"
• Section headers must be: PROFESSIONAL SUMMARY | WORK EXPERIENCE | TECHNICAL SKILLS | PROJECTS | EDUCATION
• No tables, no columns, no graphics in text — pure plain text for ATS

FORMAT THE RESUME EXACTLY LIKE THIS:
[FULL NAME]
[email] | [phone] | [location] | [LinkedIn if found]

PROFESSIONAL SUMMARY
[3-line summary]

WORK EXPERIENCE
[Company Name] | [Job Title] | [Start Date – End Date]
• [bullet]
• [bullet]
• [bullet]

TECHNICAL SKILLS
Programming Languages: [skills]
Frontend: [skills]
...

PROJECTS
[Project Name] | [Tech Stack]
• [impact line]
• [metric line]

EDUCATION
[Degree] | [University] | [Year] | CGPA: [x.x]

ALSO GENERATE:
- atsScore: Be honest and precise (0-100). Score based on: action verbs (20pts), quantified metrics (25pts), relevant keywords for "$targetRole" (25pts), proper ATS section headers (15pts), contact info completeness (15pts)
- keyStrengths: 4-5 specific, real strengths extracted from the resume (not generic)
- suggestedRoles: 4 specific job titles this person should apply for based on their ACTUAL background
- topKeywords: 12 ATS keywords recruiters use when hiring "$targetRole" — include both technical and soft skills
- linkedinSummary: Compelling 180-word LinkedIn "About" section in first person. Start with a hook, mention 2-3 achievements, end with what you're looking for.
- improvementTips: 3 specific, actionable tips to make this resume even better

Return ONLY valid JSON (no markdown, no explanation):
{
  "resumeText": "<complete formatted resume — all sections — plain text with real newlines as \\n>",
  "summary": "<the 3-line professional summary only>",
  "atsScore": <integer 0-100>,
  "keyStrengths": ["<specific strength 1>", "<specific strength 2>", "<specific strength 3>", "<specific strength 4>"],
  "suggestedRoles": ["<specific role>", "<specific role>", "<specific role>", "<specific role>"],
  "topKeywords": ["<kw1>", "<kw2>", "<kw3>", "<kw4>", "<kw5>", "<kw6>", "<kw7>", "<kw8>", "<kw9>", "<kw10>", "<kw11>", "<kw12>"],
  "linkedinSummary": "<180-word first-person LinkedIn About section>",
  "improvementTips": ["<tip 1>", "<tip 2>", "<tip 3>"]
}
''';

    final raw = await _call(prompt, maxTokens: 4096);
    final data = _decode(raw);
    return GeneratedResume.fromMap(data);
  }

  // ── Internal helpers ───────────────────────────────────────────────────────
  // Posts to backend /api/ai/chat — backend calls Groq with server-side key.
  // GROQ_API_KEY never sent to browser.
  Future<String> _call(String prompt, {required int maxTokens}) async {
    final backendUrl = AppConfig.backendUrl;
    if (backendUrl.isEmpty) {
      throw Exception(
        'Backend URL not configured. Pass --dart-define=BACKEND_URL=...',
      );
    }

    final response = await http
        .post(
          Uri.parse('$backendUrl/api/ai/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'prompt': prompt,
            'model': _model,
            'maxTokens': maxTokens,
          }),
        )
        .timeout(const Duration(seconds: 95));

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
        body['error'] ?? 'AI service error ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'AI service error');
    }
    return data['content'] as String? ?? '';
  }

  Map<String, dynamic> _decode(String raw) {
    // Step 1: strip markdown fences
    String clean = raw
        .replaceAll('```json', '')
        .replaceAll('```dart', '')
        .replaceAll('```', '')
        .trim();

    // Step 2: extract JSON object
    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      clean = clean.substring(start, end + 1);
    }

    // Step 3: fix bad control characters inside JSON string values
    // AI sometimes puts raw newlines/tabs inside strings instead of \n / \t
    // We sanitize only the characters INSIDE string values
    clean = _sanitizeJsonControlChars(clean);

    // Step 4: try parse, then retry with trailing-comma fix
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

  /// Replaces raw control characters inside JSON string values with safe escapes.
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

      // Inside a string literal: escape raw control characters
      if (inString) {
        if (code == 0x0A) {
          buf.write('\\n');
          continue;
        } // LF  → \n
        if (code == 0x0D) {
          buf.write('\\r');
          continue;
        } // CR  → \r
        if (code == 0x09) {
          buf.write('\\t');
          continue;
        } // TAB → \t
        if (code < 0x20) {
          continue;
        } // other control → drop
      }

      buf.write(ch);
    }

    return buf.toString();
  }
}
