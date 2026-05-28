import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:next_hire/core/services/app_config.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

/// Granular ATS score broken down by category so the user knows exactly
/// where points are lost and how to recover them.
class AtsSectionScore {
  final String category;
  final int score;
  final int maxScore;
  final String verdict; // short label e.g. "Strong", "Needs Work"
  final String tip; // one specific fix

  const AtsSectionScore({
    required this.category,
    required this.score,
    required this.maxScore,
    required this.verdict,
    required this.tip,
  });

  double get pct => maxScore > 0 ? score / maxScore : 0;

  factory AtsSectionScore.fromMap(Map<String, dynamic> m) => AtsSectionScore(
    category: m['category'] as String? ?? '',
    score: (m['score'] as num?)?.toInt().clamp(0, 100) ?? 0,
    maxScore: (m['maxScore'] as num?)?.toInt() ?? 10,
    verdict: m['verdict'] as String? ?? '',
    tip: m['tip'] as String? ?? '',
  );
}

/// Something the candidate is missing — shown with exact point value they'd gain.
class MissingItem {
  final String item; // what is missing
  final int pointsToGain; // how many ATS points adding it would give
  final String howToAdd; // concrete instruction
  final String priority; // 'critical' | 'high' | 'medium'
  final String section; // which section to add it to

  const MissingItem({
    required this.item,
    required this.pointsToGain,
    required this.howToAdd,
    required this.priority,
    required this.section,
  });

  factory MissingItem.fromMap(Map<String, dynamic> m) => MissingItem(
    item: m['item'] as String? ?? '',
    pointsToGain: (m['pointsToGain'] as num?)?.toInt() ?? 0,
    howToAdd: m['howToAdd'] as String? ?? '',
    priority: m['priority'] as String? ?? 'medium',
    section: m['section'] as String? ?? '',
  );

  String get priorityEmoji {
    switch (priority) {
      case 'critical':
        return '🚨';
      case 'high':
        return '🔥';
      default:
        return '💡';
    }
  }
}

/// Full generated resume with rich analysis metadata.
class GeneratedResume {
  final String resumeText;
  final String summary;

  // ATS scores
  final int atsScoreBefore; // score of uploaded/existing resume (0 if none)
  final int atsScoreAfter; // score of newly generated resume
  final bool hadExistingResume; // whether we had a baseline to compare

  // Section breakdown
  final List<AtsSectionScore> sectionScores;

  // Missing items with point values
  final List<MissingItem> missingItems;

  // Existing strengths
  final List<String> keyStrengths;

  // Job-fit
  final List<String> suggestedRoles;
  final List<String> topKeywords;

  // Bonus
  final String linkedinSummary;
  final List<String> improvementTips;

  const GeneratedResume({
    required this.resumeText,
    required this.summary,
    required this.atsScoreBefore,
    required this.atsScoreAfter,
    required this.hadExistingResume,
    required this.sectionScores,
    required this.missingItems,
    required this.keyStrengths,
    required this.suggestedRoles,
    required this.topKeywords,
    required this.linkedinSummary,
    this.improvementTips = const [],
  });

  int get atsScore => atsScoreAfter;
  int get atsImprovement => atsScoreAfter - atsScoreBefore;

  factory GeneratedResume.fromMap(
    Map<String, dynamic> m, {
    bool hadExisting = false,
  }) {
    return GeneratedResume(
      resumeText: m['resumeText'] as String? ?? '',
      summary: m['summary'] as String? ?? '',
      atsScoreBefore: (m['atsScoreBefore'] as num?)?.toInt().clamp(0, 100) ?? 0,
      atsScoreAfter: (m['atsScoreAfter'] as num?)?.toInt().clamp(0, 100) ?? 70,
      hadExistingResume: hadExisting,
      sectionScores: (m['sectionScores'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AtsSectionScore.fromMap)
          .toList(),
      missingItems: (m['missingItems'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MissingItem.fromMap)
          .toList(),
      keyStrengths: _strList(m, 'keyStrengths'),
      suggestedRoles: _strList(m, 'suggestedRoles'),
      topKeywords: _strList(m, 'topKeywords'),
      linkedinSummary: m['linkedinSummary'] as String? ?? '',
      improvementTips: _strList(m, 'improvementTips'),
    );
  }

  static List<String> _strList(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

// ─── Existing models (unchanged) ─────────────────────────────────────────────

class ImprovedResume {
  final String originalText;
  final String improvedText;
  final String improvedSummary;
  final List<Map<String, String>> bulletChanges;
  final List<String> impactAdded;
  final int atsScoreBefore;
  final int atsScoreAfter;
  final List<String> sectionsImproved;
  final List<ActionableSuggestion> actionableSuggestions;

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

class ActionableSuggestion {
  final String type;
  final String suggestion;
  final String priority;

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

class RejectionReason {
  final String category;
  final String verdict;
  final String fix;
  final String severity;

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
  static const String _model = 'llama-3.3-70b-versatile';
  static const String _fastModel = 'llama-3.3-70b-versatile';

  // ── 1. Fix My Resume ────────────────────────────────────────────────────────
  Future<ImprovedResume> fixResume({
    required String resumeText,
    String jobTitle = '',
  }) async {
    final prompt =
        '''
You are an expert resume editor and certified ATS consultant. Improve this resume honestly.
No fabricated metrics. No invented projects. Only truthful, powerful rewrites.

${jobTitle.isNotEmpty ? 'Target Role: $jobTitle\n' : ''}

EDITING RULES (every rule is mandatory):
1. SUMMARY: Rewrite with the person's actual role, skills, and experience from the resume.
2. BULLETS: Stronger WITHOUT inventing data.
   - Start with a power verb (Built, Engineered, Designed, Led, Optimized, Automated, Delivered)
   - Name the specific technology ("using Node.js and PostgreSQL" not "using backend tools")
   - If a real metric EXISTS: preserve it. If not: do NOT add a fake one.
3. STRUCTURE: Standard ATS headers — PROFESSIONAL SUMMARY | WORK EXPERIENCE | TECHNICAL SKILLS | PROJECTS | EDUCATION
4. Keep ALL original content. Remove nothing.
5. No fake companies, degrees, projects, or metrics.

ORIGINAL RESUME:
$resumeText

Return ONLY valid JSON:
{
  "improvedText": "<complete improved resume in plain text>",
  "improvedSummary": "<2-3 line summary using their actual experience>",
  "atsScoreBefore": <integer 0-100>,
  "atsScoreAfter": <integer 0-100, must exceed atsScoreBefore>,
  "sectionsImproved": ["<section names changed>"],
  "bulletChanges": [
    {"original": "<exact line>", "improved": "<honest rewrite>", "reason": "<what improved>"}
  ],
  "impactAdded": ["<only real metrics already in the resume>"],
  "actionableSuggestions": [
    {"type": "add_link|learn_skill|add_project|certification|structure", "suggestion": "<specific advice>", "priority": "high|medium|low"}
  ]
}
''';

    final raw = await _call(prompt, maxTokens: 2500, model: _fastModel);
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
You are an expert ATS consultant. Optimize this resume to maximally match the Job Description.

RULES:
1. Extract all important keywords, skills, and phrases from the JD.
2. Naturally embed missing keywords into existing bullet points (don't fabricate experience).
3. Rephrase existing bullets to mirror JD language where semantically equivalent.
4. Add missing but truthfully inferable skills to the Skills section.
5. Adjust Summary to directly echo the JD requirements.
6. Do NOT fabricate roles, projects, or companies.

JOB DESCRIPTION:
$jobDescription

RESUME:
$resumeText

Return ONLY valid JSON:
{
  "optimizedText": "<full optimized resume as plain text>",
  "keywordsAdded": ["keyword1", "keyword2"],
  "linesChanged": ["BEFORE: ... → AFTER: ..."],
  "estimatedAtsBoost": <integer 0-100>
}
''';

    final raw = await _call(prompt, maxTokens: 2500, model: _fastModel);
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
Analyze THIS specific resume honestly. Reference actual content in your feedback.

${jobTitle.isNotEmpty ? 'Role: applying for $jobTitle.\n' : ''}

Analyze these areas based on what is ACTUALLY in the resume:
ACTION_VERBS | SPECIFICITY | METRICS | SUMMARY | PROJECTS | ATS_STRUCTURE | FIRST_IMPRESSION | COMPLETENESS

RESUME:
$resumeText

Return ONLY valid JSON:
{
  "reasons": [
    {
      "category": "<dimension>",
      "verdict": "<honest verdict referencing their specific content>",
      "fix": "<actionable fix specific to their resume>",
      "severity": "critical|high|medium"
    }
  ]
}
Severity: "critical" (auto-rejected), "high" (lowers ranking), "medium" (minor gap).
Include 5-7 reasons.
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
Transform this weak project description into an impressive one for a tech resume.

RULES:
- Start with a strong action verb (Built, Developed, Engineered, Designed, Architected)
- Include tech stack used
- Add measurable impact (estimate with ~ if unknown)
- Maximum 2 sentences / 30 words
- Believable and impressive

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

  // ── 5. Selection Booster ──────────────────────────────────────────────────
  Future<SelectionBooster> getSelectionBoosters({
    required String resumeText,
    String jobTitle = '',
  }) async {
    final targetRole = jobTitle.isNotEmpty ? jobTitle : 'software developer';
    final prompt =
        '''
You are a senior tech recruiter. Analyze this SPECIFIC resume and tell the candidate what to add to get more interviews.

Target Role: $targetRole

CANDIDATE RESUME:
$resumeText

RULES — violating these makes your response useless:
1. Reference ACTUAL project names, company names from the resume.
2. Metric suggestions must name a REAL project from the resume.
3. Skill suggestions must logically extend their EXISTING tech stack.
4. Project suggestions must be buildable using their current skills.
5. NEVER give generic advice — be specific to THIS resume.

Return ONLY valid JSON (no markdown):
{
  "priorityAction": "<the single most impactful action this week>",
  "projectsToAdd": ["<project using their exact stack> — reason: <why>"],
  "skillsToAdd": ["<skill extending what they know> — complements <specific skill> — learn in <time>"],
  "metricsToAdd": ["Add to <EXACT project name>: <concrete metric>"],
  "keywordsToAdd": ["<exact missing keyword> — add to: <section name>"]
}
''';

    final raw = await _call(prompt, maxTokens: 1800);
    final data = _decode(raw);
    return SelectionBooster.fromMap(data);
  }

  // ── 6. Bundle ──────────────────────────────────────────────────────────────
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

  // ── 7. AI Resume Generator — ELITE VERSION ────────────────────────────────
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
    String existingResumeText = '',
  }) async {
    // Sanitize input text — strip Wingdings/Symbol font glyphs from OCR
    // so the model never sees (and copies) the ⊠-rendering characters.
    final cleanExistingText = _sanitizeInputText(existingResumeText);
    final hasExisting = cleanExistingText.trim().isNotEmpty;

    final expText = experiences.isEmpty
        ? 'No additional experience provided'
        : experiences.map((e) => e.toText()).join('\n\n');

    final projText = projects.isEmpty
        ? 'No additional projects provided'
        : projects.map((p) => p.toText()).join('\n\n');

    // ── Baseline ATS analysis block (only if existing resume) ────────────────
    final baselineBlock = hasExisting
        ? '''
═══════════════════════════════════════════════════════════
EXISTING RESUME (primary source of truth — read every word):
═══════════════════════════════════════════════════════════
$cleanExistingText
═══════════════════════════════════════════════════════════

EXTRACTION RULES (mandatory — follow exactly):
1. FULL NAME: The candidate's real full name is the very first heading/large text in
   the resume above. Extract it precisely. IGNORE the form "Name" field — it may
   contain a Firebase login alias (e.g. "vb") instead of the real name.
2. Extract exact company names, job titles, and date ranges from WORK EXPERIENCE.
3. Extract exact university, degree, year, and CGPA/GPA from EDUCATION.
4. Extract every skill and technology explicitly listed.
5. Extract exact project names, tech stacks, and any metrics already present.
6. Extract LinkedIn, GitHub, portfolio URLs if present.
7. Preserve ALL real metrics (e.g. "~70% reduction", "~10,000 DAU") — never
   remove or water down existing numbers.
8. Use form data ONLY for details genuinely absent from the existing resume.
'''
        : '';

    // ── The ATS scoring rubric (passed to the model so it grades itself) ─────
    // Max 100 points across 6 categories.
    // Note: \$Z is escaped so Dart does not treat it as string interpolation.
    final scoringRubric = '''
ATS SCORING RUBRIC — use this EXACT system to score both resumes (before and after):

CATEGORY                      MAX   HOW POINTS ARE AWARDED
─────────────────────────────────────────────────────────────────────────────
A. Power Action Verbs          20   +3 pts per bullet starting with power verb
                                    -2 pts per passive/weak opening ("Worked on…",
                                    "Responsible for…", "Helped with…")
B. Quantified Achievements     25   +5 pts per bullet with a real or estimated metric
                                    (~X users, ~Y% improvement, \$Z revenue)
                                    0 pts for vague outcomes ("improved performance")
C. Role-Specific Keywords      20   +2 pts per exact keyword/skill that a recruiter
                                    would search for this role appearing naturally
                                    (not keyword-stuffed in a hidden block)
D. ATS Structure & Headers     15   +3 pts each correct header:
                                    PROFESSIONAL SUMMARY, WORK EXPERIENCE,
                                    TECHNICAL SKILLS, PROJECTS, EDUCATION
                                    -5 pts for tables, columns, graphics, text boxes
E. Contact Info Completeness   10   +2 pts each: name, email, phone, location, LinkedIn/GitHub
F. Summary Quality              10  +10 if 3-line role-specific summary with achievement exists
                                    +5 if generic summary exists
                                    0 if no summary
─────────────────────────────────────────────────────────────────────────────
TOTAL                         100
''';

    final prompt =
        '''
You are a Certified Professional Resume Writer (CPRW) with 20 years of experience
placing candidates at Google, Amazon, Flipkart, Razorpay, and top Indian startups.
You understand exactly how ATS systems (Taleo, Workday, Greenhouse, iCIMS) parse resumes.

YOUR MISSION: Generate a resume for "$fullName" targeting "$targetRole" that scores
85+ / 100 on the rubric below. Also score the EXISTING resume (if provided) so the
candidate sees the before-and-after improvement.

$scoringRubric

$baselineBlock

CANDIDATE FORM DATA (fill gaps not found in existing resume):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Name     : $fullName
Email    : $email
Phone    : $phone
Location : $location
Target   : $targetRole
Exp Level: $yearsExp
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ADDITIONAL EXPERIENCE:
$expText

EDUCATION:
$education

SKILLS:
$skills

ADDITIONAL PROJECTS:
$projText

════════════════════════════════════════════════════════════
MANDATORY WRITING RULES — every rule must be followed:
════════════════════════════════════════════════════════════

RULE 1 — PROFESSIONAL SUMMARY (exactly 3 lines):
- Line 1: "[X yrs] experienced [specific role title] specializing in [2-3 core technologies from their stack]"
- Line 2: Use ONLY achievements that appear verbatim in the resume with their real numbers.
  If no numbers exist, write: "Delivered [specific project/feature] and [specific technical contribution]" — no invented figures.
- Line 3: "Seeking [targetRole] at a [company type] to [specific value proposition based on their actual background]"

RULE 2 — EXPERIENCE BULLETS (MOST CRITICAL FOR ATS SCORE):
Every single bullet MUST follow this formula:
  [Power Verb] + [specific what] + [named technology] + [outcome or description — real numbers only]

Power verbs to use (vary them — never repeat the same verb):
  Architected, Engineered, Spearheaded, Automated, Optimized, Delivered, Reduced,
  Increased, Launched, Mentored, Refactored, Integrated, Designed, Migrated, Deployed

Metric rules — HONESTY IS MANDATORY:
  - If the resume already has a real number → preserve it exactly (e.g. "~70% reduction" stays)
  - If NO metric exists in the source data → describe the technical achievement WITHOUT any number.
    Do NOT fabricate, guess, or estimate numbers. Do NOT use "~" to make up figures.
    NEVER add "~6,000 users", "~120ms latency", "~92% crash-free" unless the source says so.
  - NEVER invent companies, roles, projects, or figures not present in the data.

BAD (fabricating numbers): "Engineered REST APIs serving ~6,000 daily requests with ~120ms latency"
GOOD (honest, no invented metric): "Engineered RESTful APIs using Node.js and Firebase for real-time data sync"

BAD (fabricating users): "Built Flutter app supporting ~3,500 registered users"
GOOD (honest): "Built a cross-platform Flutter application with Firebase Auth and Firestore for role-based access control"

If the source resume says "~70% reduction in manual effort" → keep it exactly.
If the source resume says nothing about scale → describe WHAT was built and HOW, not made-up numbers.

RULE 3 — SKILLS SECTION:
Group by these exact labels (include only skills actually in their data):
  Programming Languages | Frontend Technologies | Backend Technologies |
  Databases & Storage | Cloud & DevOps | Mobile Development | Tools & Frameworks

RULE 4 — PROJECTS (make them stand out):
  Line 1: "[Project Name] | [Tech Stack] | [Live/GitHub link if found in existing resume]"
  - "Built [what it does + problem it solves] using [specific tech]"
  - "[Technical achievement or real metric if present in resume] — [how it was implemented]"

RULE 5 — CONTACT HEADER:
  $fullName
  $email | $phone | $location | [LinkedIn URL from resume if found] | [GitHub URL if found]

RULE 6 — ATS FORMATTING (critical):
  • Pure plain text — NO tables, NO columns, NO text boxes, NO graphics
  • Section headers in ALL CAPS exactly as listed in rubric
  • Dates right-aligned is standard but in plain text just put "Month Year – Month Year"
  - Use "- " (plain ASCII hyphen-space) for every bullet point — no Unicode bullets, no asterisks

═══════════════════════════════════════
SECTION ORDER (mandatory):
═══════════════════════════════════════
[FULL NAME]
[email] | [phone] | [location] | [LinkedIn if found] | [GitHub if found]

PROFESSIONAL SUMMARY
[3-line summary per Rule 1]

WORK EXPERIENCE
[Company] | [Title] | [Start – End]
- [bullet per Rule 2]
- [bullet per Rule 2]
- [bullet per Rule 2]
(3-5 bullets per role — never fewer than 3)

TECHNICAL SKILLS
Programming Languages: ...
[other categories per Rule 3]

PROJECTS
[Project Name] | [Stack] | [Link if found]
- [impact bullet — from real data only]
- [technical achievement — no invented numbers]

EDUCATION
[Degree] | [University] | [Year] | CGPA: [x.x if found]
Relevant Coursework: [if found]

CERTIFICATIONS (include only if found in resume data)
[Certification Name] | [Issuer] | [Year]

═══════════════════════════════════════
AFTER WRITING THE RESUME, ALSO GENERATE:
═══════════════════════════════════════

sectionScores: Score each ATS category using the exact rubric:
  Category names must be: "Power Action Verbs", "Quantified Achievements",
  "Role Keywords", "ATS Structure", "Contact Info", "Summary Quality"
  maxScore values: 20, 25, 20, 15, 10, 10 respectively.
  verdict: "Excellent" (>=90%), "Strong" (>=70%), "Average" (>=50%), "Weak" (<50%)
  tip: one specific fix for this category if not at max

missingItems: List specific things missing from this resume that would boost the ATS score.
  Be SPECIFIC — reference actual content from their resume.
  pointsToGain: realistic points from adding this item (1-10)
  priority: "critical" (adds 7+pts), "high" (adds 4-6pts), "medium" (adds 1-3pts)

keyStrengths: 4-5 specific strengths extracted from their ACTUAL background
  (not generic — reference real technologies/achievements from their resume)

suggestedRoles: 4 specific job titles for THEIR background
  (e.g. not just "Developer" but "React Native Mobile Developer" or "Node.js Backend Engineer")

topKeywords: Exactly 12 ATS keywords recruiters use when hiring "$targetRole"
  Mix: 8 technical (exact tool/framework names) + 4 soft/process keywords

linkedinSummary: 180-word LinkedIn "About" section in first person.
  Start with a compelling hook (not "I am a developer").
  Mention 2-3 real achievements from their resume.
  End with what opportunities you are seeking.

improvementTips: Exactly 3 highly specific tips to push this resume from current score to 90+.
  Each tip must reference something specific in THEIR resume — not generic advice.

atsScoreBefore: Apply the EXACT rubric above to the ORIGINAL uploaded resume.
  Count every signal honestly — power verbs, quantified bullets, section headers, contact completeness.
  Report the real score. Do NOT round up or inflate. If no existing resume uploaded, set to 0.

atsScoreAfter: Apply the EXACT same rubric to the newly generated resume.
  Count every signal honestly the same way. Do NOT inflate to make the improvement look bigger.
  A typical freshly generated resume scores 60-80; scoring 85+ requires LinkedIn, GitHub, 3+ metrics.
  Report the real score. The candidate needs the truth, not flattery.

════════════════════════════════
Return ONLY valid JSON — no markdown, no explanation, no preamble:
════════════════════════════════
{
  "resumeText": "<complete resume — all sections — use real \\n for newlines>",
  "summary": "<the 3-line PROFESSIONAL SUMMARY from the resume>",
  "atsScoreBefore": <integer 0-100, 0 if no existing resume>,
  "atsScoreAfter": <integer 0-100>,
  "sectionScores": [
    {
      "category": "Power Action Verbs",
      "score": <0-20>,
      "maxScore": 20,
      "verdict": "Excellent|Strong|Average|Weak",
      "tip": "<specific one-line fix>"
    },
    {
      "category": "Quantified Achievements",
      "score": <0-25>,
      "maxScore": 25,
      "verdict": "...",
      "tip": "..."
    },
    {
      "category": "Role Keywords",
      "score": <0-20>,
      "maxScore": 20,
      "verdict": "...",
      "tip": "..."
    },
    {
      "category": "ATS Structure",
      "score": <0-15>,
      "maxScore": 15,
      "verdict": "...",
      "tip": "..."
    },
    {
      "category": "Contact Info",
      "score": <0-10>,
      "maxScore": 10,
      "verdict": "...",
      "tip": "..."
    },
    {
      "category": "Summary Quality",
      "score": <0-10>,
      "maxScore": 10,
      "verdict": "...",
      "tip": "..."
    }
  ],
  "missingItems": [
    {
      "item": "<specific missing element>",
      "pointsToGain": <integer 1-10>,
      "howToAdd": "<exact instruction for THIS person>",
      "priority": "critical|high|medium",
      "section": "<which section to add it>"
    }
  ],
  "keyStrengths": ["<specific strength 1>", "<strength 2>", "<strength 3>", "<strength 4>"],
  "suggestedRoles": ["<specific role 1>", "<role 2>", "<role 3>", "<role 4>"],
  "topKeywords": ["<kw1>","<kw2>","<kw3>","<kw4>","<kw5>","<kw6>","<kw7>","<kw8>","<kw9>","<kw10>","<kw11>","<kw12>"],
  "linkedinSummary": "<180-word first-person LinkedIn About>",
  "improvementTips": ["<specific tip 1>", "<specific tip 2>", "<specific tip 3>"]
}
''';

    final raw = await _call(prompt, maxTokens: 3000, model: _fastModel);
    final data = _decode(raw);

    // ── Post-process resumeText: normalise all bullet variants ───────────────
    // The model sometimes outputs ◆ ▪ ● ▶ or other Unicode bullets that
    // certain device fonts cannot render, showing as ⊠ replacement boxes.
    // We normalise everything to the standard '• ' bullet character.
    if (data['resumeText'] is String) {
      data['resumeText'] = _normalizeBullets(data['resumeText'] as String);
    }

    return GeneratedResume.fromMap(data, hadExisting: hasExisting);
  }

  // ── Bullet normalisation ─────────────────────────────────────────────────
  /// Replaces every bullet-like character with a plain ASCII "- " hyphen.
  ///
  /// Why two passes:
  ///   Pass 1 — Named list: catches common Unicode bullets the AI explicitly uses.
  ///   Pass 2 — Regex catch-all: catches ANY symbol/private-use character
  ///            (e.g. \uF0B7 from Wingdings PDFs, \u22A0 ⊠, etc.) that sits
  ///            at the start of a line followed by whitespace. These are the
  ///            characters that render as ⊠ replacement boxes on Android/iOS
  ///            and that no explicit list can exhaustively cover.
  String _normalizeBullets(String text) {
    // Pass 1 — named Unicode bullets
    const named = [
      '\u2022', // •
      '\u00B7', // ·
      '\u2023', // ‣
      '\u25C6', // ◆
      '\u25C7', // ◇
      '\u25AA', // ▪
      '\u25B8', // ▸
      '\u25B6', // ▶
      '\u25CF', // ●
      '\u25CB', // ○
      '\u25A0', // ■
      '\u25A1', // □
      '\u27A4', // ➤
      '\u27A2', // ➢
      '\u2726', // ✦
      '\u2727', // ✧
      '\u2714', // ✔
      '\u2713', // ✓
      '\u2605', // ★
      '\u2606', // ☆
      '\u22A0', // ⊠  ← the exact character shown in the screenshot
      '\uF0B7', // private-use Wingdings bullet from symbol-font PDFs
      '\uF0A7', // private-use Wingdings hollow bullet
    ];
    String result = text;
    for (final b in named) {
      result = result.replaceAll(b, '-');
    }

    // Pass 2 — catch-all regex: any character that is NOT a standard ASCII
    // printable character (U+0020–U+007E) or common accented Latin (U+00C0–U+024F)
    // appearing at the very start of a line followed by a space or tab.
    // This captures every symbol/private-use/math/box-drawing bullet the AI
    // may copy from the source PDF, regardless of exact code point.
    result = result.replaceAllMapped(
      RegExp(r'^([^\u0020-\u007E\u00C0-\u024F\r\n])(?=[ \t])', multiLine: true),
      (_) => '-',
    );

    // Asterisk bullets
    result = result.replaceAll(RegExp(r'^\* ', multiLine: true), '- ');
    // Collapse double-dashes left by replacements above
    result = result.replaceAll(RegExp(r'^--+ ', multiLine: true), '- ');
    return result;
  }

  /// Sanitises [text] coming from OCR/PDF before embedding in an AI prompt.
  /// Strips or replaces private-use-area and symbol characters that OCR
  /// extracts from Wingdings/Symbol fonts — these cause the model to copy the
  /// weird glyphs into its output (shown as ⊠ in Flutter).
  String _sanitizeInputText(String text) => _normalizeBullets(text);
  // ── Internal helpers ───────────────────────────────────────────────────────
  Future<String> _call(
    String prompt, {
    required int maxTokens,
    String? model,
  }) async {
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
            'model': model ?? _model,
            'maxTokens': maxTokens,
          }),
        )
        .timeout(
          const Duration(seconds: 90),
          onTimeout: () =>
              throw Exception('Request timed out. Please try again.'),
        );

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
