// ─────────────────────────────────────────────────────────────────────────
// JD KEYWORD MATCH SERVICE
//
// A 100% on-device, zero-API-cost keyword matcher — the same core idea
// behind popular external "resume vs job description" checkers. Paste any
// job posting and instantly see the match %, which keywords the resume
// already covers, and which are missing.
//
// This intentionally does NOT rewrite the resume — it only scores and
// lists keywords. Actually rewriting bullets to weave in missing keywords
// is what the AI-powered "Job Description Match" premium tool does; this
// free scanner is the fast, unlimited-use first step that shows *why*
// that would help.
// ─────────────────────────────────────────────────────────────────────────

enum KeywordPriority { critical, niceToHave, general }

class JdKeyword {
  final String term;
  final bool matched;
  final KeywordPriority priority;

  const JdKeyword({required this.term, required this.matched, required this.priority});
}

class JdMatchResult {
  final int matchPercent;
  final List<JdKeyword> matched;
  final List<JdKeyword> missing;
  final int totalKeywords;
  final String jdWordCount;

  const JdMatchResult({
    required this.matchPercent,
    required this.matched,
    required this.missing,
    required this.totalKeywords,
    required this.jdWordCount,
  });

  List<JdKeyword> get missingCritical =>
      missing.where((k) => k.priority == KeywordPriority.critical).toList();
  List<JdKeyword> get missingNiceToHave =>
      missing.where((k) => k.priority == KeywordPriority.niceToHave).toList();
  List<JdKeyword> get missingGeneral =>
      missing.where((k) => k.priority == KeywordPriority.general).toList();

  String get verdict {
    if (matchPercent >= 75) return 'Strong match';
    if (matchPercent >= 50) return 'Decent match — a few gaps to close';
    if (matchPercent >= 25) return 'Weak match — this resume needs real tailoring';
    return 'Very low match — consider whether this role is the right fit';
  }
}

class JdMatchService {
  JdMatchService._();

  // ── Curated skill dictionary ────────────────────────────────────────────
  // Ordered longest-phrase-first so multi-word terms are matched before
  // their single-word substrings (e.g. "state management" before "state").
  static const List<String> _skillDictionary = [
    // Languages
    'python', 'java', 'javascript', 'typescript', 'dart', 'kotlin', 'swift', 'c++', 'c#',
    'golang', 'go', 'rust', 'php', 'ruby', 'scala', 'objective-c', 'sql', 'html', 'html5',
    'css', 'css3', 'bash', 'shell scripting', 'perl', 'matlab',
    // Mobile / frontend
    'flutter', 'react native', 'android', 'android sdk', 'ios', 'react', 'react.js', 'angular',
    'vue', 'vue.js', 'next.js', 'nuxt', 'jetpack compose', 'swiftui', 'xamarin', 'ionic',
    'responsive design', 'tailwind css', 'bootstrap', 'material design', 'redux',
    // Backend / frameworks
    'node.js', 'express.js', 'express', 'django', 'flask', 'fastapi', 'spring boot', 'spring',
    'laravel', '.net', 'asp.net', 'graphql', 'rest api', 'restful api', 'grpc', 'microservices',
    'websocket', 'soap api', 'api integration', 'third party integration',
    // Data / databases
    'mysql', 'postgresql', 'mongodb', 'firebase', 'firestore', 'redis', 'sqlite', 'oracle',
    'dynamodb', 'elasticsearch', 'cassandra', 'supabase', 'nosql', 'database design',
    'data modeling', 'etl',
    // Cloud / devops
    'aws', 'azure', 'gcp', 'google cloud', 'docker', 'kubernetes', 'ci/cd', 'jenkins',
    'github actions', 'terraform', 'ansible', 'linux', 'nginx', 'cloudflare', 'devops',
    'load balancing', 'serverless',
    // AI / data science
    'machine learning', 'deep learning', 'tensorflow', 'pytorch', 'nlp', 'computer vision',
    'pandas', 'numpy', 'scikit-learn', 'data analysis', 'data science', 'llm', 'generative ai',
    'opencv', 'keras', 'power bi', 'tableau', 'data visualization', 'big data', 'hadoop', 'spark',
    // Tools
    'git', 'github', 'gitlab', 'bitbucket', 'jira', 'figma', 'postman', 'vs code',
    'android studio', 'xcode', 'confluence', 'slack', 'trello', 'notion',
    // Methodology
    'agile', 'scrum', 'kanban', 'waterfall', 'tdd', 'unit testing', 'widget testing',
    'integration testing', 'ci/cd pipeline', 'code review', 'pair programming',
    // Architecture / state management
    'state management', 'provider', 'riverpod', 'bloc', 'getx', 'mvvm', 'mvc', 'mvi',
    'clean architecture', 'design patterns', 'solid principles', 'dependency injection',
    // Payments / commerce
    'razorpay', 'stripe', 'payment gateway', 'paypal',
    // Testing / QA
    'selenium', 'cypress', 'jest', 'junit', 'espresso', 'manual testing', 'automation testing',
    'qa', 'quality assurance',
    // Security
    'oauth', 'jwt', 'authentication', 'authorization', 'encryption', 'penetration testing',
    'owasp',
    // Soft / general professional
    'leadership', 'communication', 'problem solving', 'project management', 'stakeholder management',
    'time management', 'critical thinking', 'collaboration', 'cross-functional', 'mentoring',
    'client interaction', 'presentation skills', 'analytical skills', 'attention to detail',
    // Design
    'ui/ux', 'ui design', 'ux design', 'wireframing', 'prototyping', 'user research',
    'design system', 'accessibility',
  ];

  static const List<String> _stopwords = [
    'a', 'an', 'the', 'and', 'or', 'but', 'if', 'then', 'else', 'for', 'of', 'to', 'in', 'on',
    'at', 'by', 'with', 'without', 'within', 'from', 'into', 'onto', 'is', 'are', 'was', 'were',
    'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'shall',
    'should', 'may', 'might', 'must', 'can', 'could', 'this', 'that', 'these', 'those', 'i',
    'you', 'he', 'she', 'it', 'we', 'they', 'them', 'their', 'our', 'your', 'his', 'her', 'its',
    'as', 'not', 'no', 'yes', 'so', 'than', 'too', 'very', 'just', 'also', 'more', 'most',
    'some', 'any', 'all', 'each', 'every', 'other', 'another', 'such', 'only', 'own', 'same',
    'once', 'here', 'there', 'when', 'where', 'why', 'how', 'what', 'which', 'who', 'whom',
    'about', 'above', 'after', 'again', 'against', 'below', 'between', 'during', 'before',
    'while', 'up', 'down', 'out', 'off', 'over', 'under', 'further', 'across', 'along', 'around',
    'behind', 'beneath', 'beside', 'beyond', 'except', 'inside', 'near', 'outside', 'since',
    'through', 'throughout', 'toward', 'underneath', 'until', 'upon', 'looking', 'join', 'our',
    'team', 'responsibilities', 'requirements', 'preferred', 'nice', 'have', 'plus', 'bonus',
    'years', 'year', 'experience', 'strong', 'good', 'excellent', 'knowledge', 'understanding',
    'ability', 'skills', 'work', 'working', 'role', 'position', 'candidate', 'candidates',
    'applicant', 'apply', 'job', 'description', 'including', 'etc', 'using', 'use', 'used',
    'related', 'field', 'similar', 'minimum', 'least', 'we',
  ];

  static const List<String> _criticalTriggers = [
    'requirement', 'must have', 'must-have', 'required', 'minimum qualification',
    'what you need', 'qualifications', 'you have', 'we expect',
  ];
  static const List<String> _niceTriggers = [
    'preferred', 'nice to have', 'nice-to-have', 'bonus', 'good to have', 'a plus', 'plus points',
    'brownie points', 'added advantage',
  ];
  static const List<String> _neutralTriggers = [
    'responsibilit', 'day to day', 'role overview', 'about the role', 'duties',
    'about us', 'about the company', 'about the team', 'perks', 'benefits',
  ];

  // ── Public entry point ──────────────────────────────────────────────────

  static JdMatchResult match(String resumeText, String jdText) {
    final zones = _tagZones(jdText);
    final dictHits = _dictionaryMatches(jdText);
    final freqHits = _frequencyKeywords(jdText);

    // Preserve order, de-dupe, dictionary terms take priority over frequency ones.
    final seen = <String>{};
    final allTerms = <String>[];
    for (final t in [...dictHits, ...freqHits]) {
      if (seen.add(t)) allTerms.add(t);
    }

    final resumeLower = resumeText.toLowerCase();
    final matched = <JdKeyword>[];
    final missing = <JdKeyword>[];

    for (final term in allTerms) {
      final priority = _priorityFor(term, zones);
      final isMatched = _appearsIn(term, resumeLower);
      final kw = JdKeyword(term: term, matched: isMatched, priority: priority);
      if (isMatched) {
        matched.add(kw);
      } else {
        missing.add(kw);
      }
    }

    final pct = allTerms.isEmpty ? 0 : ((matched.length / allTerms.length) * 100).round();
    final jdWords = jdText.trim().isEmpty
        ? 0
        : jdText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return JdMatchResult(
      matchPercent: pct,
      matched: matched,
      missing: missing,
      totalKeywords: allTerms.length,
      jdWordCount: jdWords.toString(),
    );
  }

  // ── Dictionary matching ─────────────────────────────────────────────────

  // ── Boundary-safe matching helper ───────────────────────────────────────
  // Plain \b fails for terms that start/end in a symbol (C++, C#, .NET) —
  // \b only fires at a word/non-word transition, and a symbol next to
  // whitespace is a non-word/non-word transition, so \b never matches
  // there. This checks "not glued to a letter/digit" on both sides instead,
  // which works whether that side is a symbol, whitespace, or string edge.
  static RegExp _wordSafePattern(String term) {
    final escaped = RegExp.escape(term);
    return RegExp(
      r'(?:^|[^A-Za-z0-9])' + escaped + r's?(?:$|[^A-Za-z0-9])',
      caseSensitive: false,
    );
  }

  static List<String> _dictionaryMatches(String text) {
    final sorted = [..._skillDictionary]..sort((a, b) => b.length.compareTo(a.length));
    final found = <String>[];
    for (final skill in sorted) {
      if (_wordSafePattern(skill).hasMatch(text)) found.add(skill);
    }
    return found;
  }

  // ── Frequency-based fallback extraction ─────────────────────────────────
  // Catches JD-specific terms not in our dictionary (product names, domain
  // jargon) by looking for words that repeat often — a decent proxy for
  // "this JD considers this important".

  static List<String> _frequencyKeywords(String text, {int minCount = 2, int topN = 15}) {
    final words = RegExp(r"[A-Za-z][A-Za-z+.#\-]{1,}")
        .allMatches(text)
        .map((m) => m.group(0)!.toLowerCase())
        .where((w) => !_stopwords.contains(w) && w.length > 2)
        .toList();

    final counts = <String, int>{};
    for (final w in words) {
      counts[w] = (counts[w] ?? 0) + 1;
    }
    final entries = counts.entries.where((e) => e.value >= minCount).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(topN).map((e) => e.key).toList();
  }

  // ── Plural/singular-tolerant matching ───────────────────────────────────

  static bool _appearsIn(String keyword, String lowText) {
    if (_wordSafePattern(keyword).hasMatch(lowText)) return true;
    if (keyword.endsWith('s') && keyword.length > 3) {
      if (_wordSafePattern(keyword.substring(0, keyword.length - 1)).hasMatch(lowText)) {
        return true;
      }
    }
    return false;
  }

  // ── Critical vs nice-to-have zone tagging ───────────────────────────────

  static List<_Zone> _tagZones(String jdText) {
    final lines = jdText.split('\n');
    var zone = KeywordPriority.general;
    final tagged = <_Zone>[];
    for (final raw in lines) {
      final low = raw.trim().toLowerCase();
      if (_neutralTriggers.any((t) => low.contains(t))) {
        zone = KeywordPriority.general;
      } else if (_niceTriggers.any((t) => low.contains(t))) {
        zone = KeywordPriority.niceToHave;
      } else if (_criticalTriggers.any((t) => low.contains(t))) {
        zone = KeywordPriority.critical;
      }
      tagged.add(_Zone(zone, raw.toLowerCase()));
    }
    return tagged;
  }

  static KeywordPriority _priorityFor(String term, List<_Zone> zones) {
    final pattern = _wordSafePattern(term);
    var sawNice = false;
    var sawGeneral = false;
    for (final z in zones) {
      if (pattern.hasMatch(z.text)) {
        if (z.priority == KeywordPriority.critical) return KeywordPriority.critical;
        if (z.priority == KeywordPriority.niceToHave) sawNice = true;
        if (z.priority == KeywordPriority.general) sawGeneral = true;
      }
    }
    if (sawNice) return KeywordPriority.niceToHave;
    if (sawGeneral) return KeywordPriority.general;
    return KeywordPriority.critical; // default: unzoned lines are treated as core requirements
  }
}

class _Zone {
  final KeywordPriority priority;
  final String text;
  const _Zone(this.priority, this.text);
}
