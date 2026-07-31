// ─────────────────────────────────────────────────────────────────────────
// LOCAL RESUME ANALYZER
//
// A 100% on-device, zero-API-cost resume scanner. It runs instantly (no
// network call, no Groq token spend) the moment resume text is available,
// so users get real, specific feedback before — or even without — ever
// running the AI-powered ATS Check.
//
// This is deliberately NOT a replacement for AiService.analyzeAtsOnly: that
// call reads the resume the way a human recruiter would and reasons about
// it. This engine instead reproduces the mechanical checks that a real ATS
// parser and a quick recruiter skim actually do — contact fields present,
// section headers recognizable, bullets quantified, verbs strong, no
// parsing landmines — so it is intentionally rule-based and fully
// explainable. Together they give a "instant + free" layer and a
// "deep + AI" layer.
// ─────────────────────────────────────────────────────────────────────────

/// Pass/warn/fail severity for a single [ResumeCheck].
enum CheckStatus { pass, warn, fail }

/// One specific, human-readable finding produced by the scanner.
class ResumeCheck {
  final String title;
  final String message;
  final CheckStatus status;
  final String category;

  const ResumeCheck({
    required this.title,
    required this.message,
    required this.status,
    required this.category,
  });
}

/// Score for one of the five scoring categories that make up the total.
class ScanCategoryScore {
  final String name;
  final int score;
  final int maxScore;

  const ScanCategoryScore({
    required this.name,
    required this.score,
    required this.maxScore,
  });

  double get ratio => maxScore == 0 ? 0 : score / maxScore;
}

/// Full result of a [LocalResumeAnalyzer.analyze] pass.
class LocalScanResult {
  final int score;
  final int rawScore;
  final bool wasCapped;
  final String? capReason;
  final List<ScanCategoryScore> categories;
  final List<ResumeCheck> checks;

  final int wordCount;
  final double estimatedPages;
  final int bulletCount;
  final int strongVerbCount;
  final int weakVerbCount;
  final int quantifiedCount;

  final bool hasEmail;
  final bool hasPhone;
  final bool hasLinkedIn;
  final bool hasGithub;
  final List<String> sectionsFound;
  final List<String> sectionsMissing;
  final List<String> clichesFound;
  final List<String> personalDetailsFound;
  final List<String> runTogetherSamples;

  final String rawText;

  const LocalScanResult({
    required this.score,
    required this.rawScore,
    required this.wasCapped,
    required this.capReason,
    required this.categories,
    required this.checks,
    required this.wordCount,
    required this.estimatedPages,
    required this.bulletCount,
    required this.strongVerbCount,
    required this.weakVerbCount,
    required this.quantifiedCount,
    required this.hasEmail,
    required this.hasPhone,
    required this.hasLinkedIn,
    required this.hasGithub,
    required this.sectionsFound,
    required this.sectionsMissing,
    required this.clichesFound,
    required this.personalDetailsFound,
    required this.runTogetherSamples,
    required this.rawText,
  });

  int get passCount => checks.where((c) => c.status == CheckStatus.pass).length;
  int get warnCount => checks.where((c) => c.status == CheckStatus.warn).length;
  int get failCount => checks.where((c) => c.status == CheckStatus.fail).length;

  String get scoreLabel {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Needs Work';
    return 'Weak';
  }
}

class LocalResumeAnalyzer {
  LocalResumeAnalyzer._();

  // ── Section headers ─────────────────────────────────────────────────────

  static const Map<String, List<String>> _sectionHeaders = {
    'Summary': ['career objective', 'objective', 'professional summary', 'summary', 'profile', 'about me'],
    'Education': ['education', 'academic background', 'academic qualification', 'academic qualifications'],
    'Skills': ['technical skills', 'skills', 'core competencies', 'areas of expertise', 'tech stack', 'technologies'],
    'Experience': ['work experience', 'professional experience', 'employment history', 'experience', 'career history', 'internships', 'internship'],
    'Projects': ['projects', 'personal projects', 'academic projects', 'key projects', 'academic project', 'personal project'],
    'Certifications': ['certifications', 'certification', 'achievements', 'awards', 'honors', 'publications'],
  };

  static const List<String> _coreSections = ['Experience', 'Education', 'Skills'];

  // ── Verb / phrase vocabularies ──────────────────────────────────────────

  static const List<String> _verbLemmas = [
    'build', 'develop', 'design', 'implement', 'deploy', 'optimize', 'integrate', 'architect',
    'create', 'maintain', 'collaborate', 'lead', 'manage', 'launch', 'automate', 'reduce',
    'increase', 'improve', 'deliver', 'ship', 'engineer', 'spearhead', 'orchestrate', 'streamline',
    'mentor', 'train', 'analyze', 'research', 'author', 'establish', 'negotiate', 'resolve',
    'migrate', 'refactor', 'scale', 'configure', 'administer', 'coordinate', 'execute', 'drive',
    'achieve', 'generate', 'produce', 'initiate', 'organize', 'present', 'publish', 'write',
    'test', 'debug', 'troubleshoot', 'solve', 'plan', 'define', 'conduct', 'perform', 'review',
    'evaluate', 'assess', 'identify', 'enhance', 'upgrade', 'customize', 'monitor', 'oversee',
    'supervise', 'direct', 'guide', 'facilitate', 'enable', 'boost', 'accelerate', 'cut', 'save',
    'grow', 'expand', 'transform', 'modernize', 'simplify', 'standardize', 'consolidate',
    'translate', 'convert', 'compile', 'extract', 'process', 'validate', 'verify', 'audit',
    'secure', 'provision', 'release', 'iterate', 'prototype', 'strategize', 'onboard', 'recruit',
    'hire', 'liaise', 'pioneer', 'champion',
  ];

  static const Map<String, String> _irregularPast = {
    'build': 'built', 'lead': 'led', 'write': 'wrote', 'drive': 'drove', 'cut': 'cut',
    'set': 'set', 'run': 'ran', 'spearhead': 'spearheaded', 'grow': 'grew',
    'ship': 'shipped', 'debug': 'debugged', 'plan': 'planned', 'oversee': 'oversaw',
  };

  // Verbs whose gerund doubles the final consonant (ship -> shipping, not
  // shiping) — the regular lemma+'ing' rule below gets these wrong. Also
  // covers 'oversee', whose double-e already ends in 'e' but needs the
  // whole lemma kept (overseeing), not the usual "drop the trailing e" rule.
  static const Map<String, String> _irregularGerund = {
    'ship': 'shipping', 'debug': 'debugging', 'plan': 'planning', 'cut': 'cutting',
    'oversee': 'overseeing',
  };

  static final Set<String> _strongVerbs = _buildStrongVerbSet();

  static Set<String> _buildStrongVerbSet() {
    final set = <String>{};
    for (final lemma in _verbLemmas) {
      set.add(lemma);
      set.add('${lemma}s');
      if (_irregularGerund.containsKey(lemma)) {
        set.add(_irregularGerund[lemma]!);
      } else if (lemma.endsWith('e')) {
        set.add('${lemma.substring(0, lemma.length - 1)}ing');
      } else {
        set.add('${lemma}ing');
      }
      if (_irregularPast.containsKey(lemma)) {
        set.add(_irregularPast[lemma]!);
      } else if (lemma.endsWith('e')) {
        set.add('${lemma}d');
      } else if (lemma.endsWith('y') && !'aeiou'.contains(lemma[lemma.length - 2])) {
        set.add('${lemma.substring(0, lemma.length - 1)}ied');
      } else {
        set.add('${lemma}ed');
      }
    }
    set.add('troubleshot'); // alternate accepted past tense of "troubleshoot"
    return set;
  }

  static const List<String> _weakStarts = [
    'responsible for', 'worked on', 'helped with', 'assisted with', 'assisted in',
    'duties included', 'in charge of', 'tasked with', 'involved in', 'was responsible',
    'was involved', 'were completed', 'was given', 'was assigned', 'took part in',
  ];

  static const List<String> _cliches = [
    'hardworking', 'hard-working', 'team player', 'go-getter', 'go getter',
    'detail oriented', 'detail-oriented', 'self motivated', 'self-motivated',
    'think outside the box', 'results driven', 'results-driven', 'fast learner',
    'dynamic professional', 'passion for excellence', 'synergy', 'proactive individual',
    'excellent communication skills', 'good communication skills', 'people person',
    'outside the box thinker', 'strong work ethic', 'highly motivated',
  ];

  static const List<String> _personalDetailKeywords = [
    "father's name", "mother's name", "date of birth", "d.o.b", "marital status",
    'religion', 'nationality', 'gender:',
  ];

  // ── Regex helpers ───────────────────────────────────────────────────────

  static final RegExp _emailRe = RegExp(r"\b[\w.%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b");
  static final RegExp _phoneCandidateRe = RegExp(r'(\+?\d[\d\s\-().]{7,}\d)');
  static final RegExp _linkedinRe = RegExp(r'linkedin\.com/in/[\w\-]+', caseSensitive: false);
  static final RegExp _githubRe = RegExp(r'github\.com/[\w\-]+', caseSensitive: false);

  static final RegExp _monthTokenRe =
      RegExp(r'^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?$', caseSensitive: false);
  static final RegExp _connectorTokenRe =
      RegExp(r'^(to|till|until|present|current|now)$|^[-–—]+$', caseSensitive: false);
  static final RegExp _numericTokenRe = RegExp(r'^\d{1,4}(st|nd|rd|th)?\.?,?$', caseSensitive: false);

  static final RegExp _companySuffixRe = RegExp(
    r'\b(pvt\.?\s*ltd\.?|private\s+limited|llc|inc\.?|technologies|solutions|corp\.?|limited|systems)\b',
    caseSensitive: false,
  );

  static final RegExp _passiveRe = RegExp(r'\b(was|were|is|are|been|being|be)\s+\w+(ed|en)\b', caseSensitive: false);

  static final RegExp _quantRe = RegExp(
    r'(\d[\d,.]*\s*%|\$\s*\d|\u20b9\s*\d|\d[\d,]*\+|\b\d+\s*(users?|downloads?|hours?|days?|weeks?|'
    r'months?|years?|customers?|clients?|members?|projects?|requests?|records?|rows?|ms|sec|seconds?)\b|\b\d{2,}\b)',
    caseSensitive: false,
  );

  static final RegExp _iPronounRe = RegExp(r'\bI\b'); // case sensitive — the pronoun is always capitalized
  static final RegExp _myPronounRe = RegExp(r'\bmy\b', caseSensitive: false);
  static final RegExp _mePronounRe = RegExp(r'\bme\b', caseSensitive: false);
  static final RegExp _myselfPronounRe = RegExp(r'\bmyself\b', caseSensitive: false);

  static final RegExp _runTogetherRe = RegExp(r'\b[A-Za-z]{25,}\b');

  static const List<String> _bulletGlyphs = ['•', '-', '*', '▪', '●', '▶', '➤', '◦', '‣', '·'];

  // ── Public entry point ──────────────────────────────────────────────────

  static LocalScanResult analyze(String resumeText) {
    final text = resumeText.trim();

    // 1. Contact info
    final hasEmail = _emailRe.hasMatch(text);
    final hasLinkedIn = _linkedinRe.hasMatch(text);
    final hasGithub = _githubRe.hasMatch(text);
    final hasPhone = _phoneCandidateRe.allMatches(text).any((m) {
      final digits = m.group(1)!.replaceAll(RegExp(r'\D'), '');
      return digits.length >= 10 && digits.length <= 13;
    });

    // 2. Section segmentation
    final segments = _segment(text);
    final sectionsFound = segments.map((s) => s.category).toSet()
      ..removeWhere((c) => c == 'header' || c == 'other');
    final sectionsMissing = _coreSections.where((s) => !sectionsFound.contains(s)).toList();

    // 3. Bullet / content-line extraction (Experience + Projects only)
    final contentLines = <String>[];
    for (final seg in segments) {
      if (seg.category == 'Experience' || seg.category == 'Projects') {
        contentLines.addAll(_extractContentLines(seg.lines));
      }
    }

    // 4. Action verbs
    var strong = 0, weak = 0;
    for (final line in contentLines) {
      final low = line.toLowerCase();
      final firstWordMatch = RegExp(r"^[a-zA-Z']+").firstMatch(low.trimLeft());
      final fw = firstWordMatch?.group(0) ?? '';
      if (_weakStarts.any((w) => low.startsWith(w))) {
        weak++;
      } else if (_strongVerbs.contains(fw)) {
        strong++;
      }
    }

    // 5. Quantified achievements
    final quantified = contentLines.where((l) => _quantRe.hasMatch(l)).length;

    // 6. Personal pronouns
    final pronounCount = _iPronounRe.allMatches(text).length +
        _myPronounRe.allMatches(text).length +
        _mePronounRe.allMatches(text).length +
        _myselfPronounRe.allMatches(text).length;

    // 7. Clichés
    final lowerText = text.toLowerCase();
    final clichesFound = _cliches.where((c) => lowerText.contains(c)).toList();

    // 8. Passive voice
    final passiveCount = contentLines.where((l) => _passiveRe.hasMatch(l)).length;

    // 9. Run-together / parse-risk words
    final runTogetherMatches = _runTogetherRe.allMatches(text).map((m) => m.group(0)!).toList();
    final runTogetherSamples = runTogetherMatches.length >= 2 ? runTogetherMatches : <String>[];

    // 10. Date format consistency
    final dateFormatsUsed = _detectDateFormats(text);

    // 11. Personal detail oversharing
    final personalFound = _personalDetailKeywords.where((k) => lowerText.contains(k)).toList();

    // 12. Word count / pages
    final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final pages = wordCount / 550.0;

    // ── Scoring ──────────────────────────────────────────────────────────

    // Category 1: Contact & Structure (20)
    var contactScore = 0;
    contactScore += hasEmail ? 6 : 0;
    contactScore += hasPhone ? 4 : 0;
    contactScore += hasLinkedIn ? 5 : 0;
    final coreFoundRatio =
        _coreSections.where((s) => sectionsFound.contains(s)).length / _coreSections.length;
    contactScore += (5 * coreFoundRatio).round();

    // Category 2: ATS Parseability (20)
    var parseScore = 0;
    parseScore += runTogetherSamples.isEmpty ? 10 : 3;
    if (dateFormatsUsed.isEmpty) {
      parseScore += 5;
    } else {
      parseScore += dateFormatsUsed.length <= 1 ? 5 : 1;
    }
    if (pages >= 0.75 && pages <= 2.2) {
      parseScore += 5;
    } else if (pages < 0.75) {
      parseScore += 3;
    } else {
      parseScore += 2;
    }

    // Category 3: Language & Impact (30)
    final verbRatio = contentLines.isEmpty ? 0.0 : strong / contentLines.length;
    final quantRatio = contentLines.isEmpty ? 0.0 : quantified / contentLines.length;
    final impactScore =
        (verbRatio.clamp(0, 1) * 15).round() + ((quantRatio / 0.4).clamp(0, 1) * 15).round();

    // Category 4: Professional Tone (15)
    final toneScore =
        (8 - pronounCount.clamp(0, 8)).round() + (7 - (clichesFound.length * 1.5).clamp(0, 7)).round();

    // Category 5: Formatting Hygiene (15)
    final passiveRatio = contentLines.isEmpty ? 0.0 : passiveCount / contentLines.length;
    final hygieneScore = ((1 - passiveRatio).clamp(0, 1) * 8).round() +
        (7 - (3 * personalFound.length)).clamp(0, 7).round();

    final rawTotal = contactScore + parseScore + impactScore + toneScore + hygieneScore;

    var total = rawTotal;
    var capped = false;
    String? capReason;
    if (runTogetherSamples.isNotEmpty) {
      final gated = rawTotal > 50 ? 50 : rawTotal;
      if (gated < rawTotal) {
        capped = true;
        capReason =
            'Your file has text that looks merged together with no spaces — a strong sign a real ATS '
            'parser would also fail to read it correctly. This caps your score until it\'s fixed, no '
            'matter how well the bullets underneath are written.';
        total = gated;
      }
    }

    final categories = [
      ScanCategoryScore(name: 'Contact & Structure', score: contactScore, maxScore: 20),
      ScanCategoryScore(name: 'ATS Parseability', score: parseScore, maxScore: 20),
      ScanCategoryScore(name: 'Language & Impact', score: impactScore, maxScore: 30),
      ScanCategoryScore(name: 'Professional Tone', score: toneScore, maxScore: 15),
      ScanCategoryScore(name: 'Formatting Hygiene', score: hygieneScore, maxScore: 15),
    ];

    final checks = _buildChecks(
      hasEmail: hasEmail,
      hasPhone: hasPhone,
      hasLinkedIn: hasLinkedIn,
      hasGithub: hasGithub,
      sectionsMissing: sectionsMissing,
      contentLineCount: contentLines.length,
      strong: strong,
      weak: weak,
      quantified: quantified,
      pronounCount: pronounCount,
      clichesFound: clichesFound,
      passiveCount: passiveCount,
      runTogetherFound: runTogetherSamples.isNotEmpty,
      dateFormatCount: dateFormatsUsed.length,
      personalFound: personalFound,
      wordCount: wordCount,
      pages: pages,
    );

    return LocalScanResult(
      score: total,
      rawScore: rawTotal,
      wasCapped: capped,
      capReason: capReason,
      categories: categories,
      checks: checks,
      wordCount: wordCount,
      estimatedPages: pages,
      bulletCount: contentLines.length,
      strongVerbCount: strong,
      weakVerbCount: weak,
      quantifiedCount: quantified,
      hasEmail: hasEmail,
      hasPhone: hasPhone,
      hasLinkedIn: hasLinkedIn,
      hasGithub: hasGithub,
      sectionsFound: sectionsFound.toList(),
      sectionsMissing: sectionsMissing,
      clichesFound: clichesFound,
      personalDetailsFound: personalFound,
      runTogetherSamples: runTogetherSamples.take(3).toList(),
      rawText: text,
    );
  }

  // ── Section segmentation ────────────────────────────────────────────────

  static String? _headerCategory(String line) {
    final stripped = line.trim().replaceAll(RegExp(r':$'), '').trim();
    if (stripped.isEmpty) return null;
    final wordCount = stripped.split(RegExp(r'\s+')).length;
    if (wordCount > 5) return null;
    final low = stripped.toLowerCase();
    for (final entry in _sectionHeaders.entries) {
      for (final phrase in entry.value) {
        if (low == phrase || low == '${phrase}s') return entry.key;
      }
    }
    return null;
  }

  static List<_Segment> _segment(String text) {
    final lines = text.split('\n');
    final segments = <_Segment>[];
    var currentCategory = 'header';
    var currentLines = <String>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final category = _headerCategory(line);
      if (category != null) {
        segments.add(_Segment(currentCategory, currentLines));
        currentCategory = category;
        currentLines = [];
      } else {
        currentLines.add(line);
      }
    }
    segments.add(_Segment(currentCategory, currentLines));
    return segments;
  }

  // ── Content-line (bullet) extraction ────────────────────────────────────

  static bool _isPureDateLine(String stripped) {
    final tokens = stripped.replaceAll('/', ' / ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty || tokens.length > 8) return false;
    for (final t in tokens) {
      if (t == '/') continue;
      if (_monthTokenRe.hasMatch(t) || _connectorTokenRe.hasMatch(t) || _numericTokenRe.hasMatch(t)) {
        continue;
      }
      return false;
    }
    return true;
  }

  static List<String> _extractContentLines(List<String> segLines) {
    final content = <String>[];
    for (final raw in segLines) {
      var stripped = raw;
      var hasGlyph = false;
      for (final g in _bulletGlyphs) {
        if (stripped.startsWith(g)) {
          hasGlyph = true;
          stripped = stripped.substring(1).trim();
          break;
        }
      }
      final wc = stripped.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (_isPureDateLine(stripped)) continue;
      if (wc < 4 && !hasGlyph) continue; // title/company/project-name line
      if (!hasGlyph &&
          wc < 8 &&
          (' ${stripped.toLowerCase()} '.contains(' at ') || _companySuffixRe.hasMatch(stripped))) {
        continue; // "Role at Company" style line
      }
      content.add(stripped);
    }
    return content;
  }

  // ── Date-format consistency ─────────────────────────────────────────────

  static Set<String> _detectDateFormats(String text) {
    final formats = <String, RegExp>{
      'mm/yyyy': RegExp(r'\b\d{1,2}/\d{4}\b'),
      'month yyyy': RegExp(
        r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{4}\b',
        caseSensitive: false,
      ),
      'dd month yyyy': RegExp(
        r'\b\d{1,2}(st|nd|rd|th)?\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{4}\b',
        caseSensitive: false,
      ),
      'yyyy-yyyy': RegExp(r'\b\d{4}\s*[-–]\s*\d{4}\b'),
    };
    final used = <String>{};
    formats.forEach((name, re) {
      if (re.hasMatch(text)) used.add(name);
    });
    return used;
  }

  // ── Check list (human-readable findings) ────────────────────────────────

  static List<ResumeCheck> _buildChecks({
    required bool hasEmail,
    required bool hasPhone,
    required bool hasLinkedIn,
    required bool hasGithub,
    required List<String> sectionsMissing,
    required int contentLineCount,
    required int strong,
    required int weak,
    required int quantified,
    required int pronounCount,
    required List<String> clichesFound,
    required int passiveCount,
    required bool runTogetherFound,
    required int dateFormatCount,
    required List<String> personalFound,
    required int wordCount,
    required double pages,
  }) {
    final checks = <ResumeCheck>[];
    const cat1 = 'Contact & Structure';
    const cat2 = 'ATS Parseability';
    const cat3 = 'Language & Impact';
    const cat4 = 'Professional Tone';
    const cat5 = 'Formatting Hygiene';

    checks.add(ResumeCheck(
      title: 'Email address',
      message: hasEmail ? 'Found a valid email address.' : 'No email address detected — add one at the top.',
      status: hasEmail ? CheckStatus.pass : CheckStatus.fail,
      category: cat1,
    ));
    checks.add(ResumeCheck(
      title: 'Phone number',
      message: hasPhone ? 'Found a phone number.' : 'No phone number detected.',
      status: hasPhone ? CheckStatus.pass : CheckStatus.warn,
      category: cat1,
    ));
    checks.add(ResumeCheck(
      title: 'LinkedIn profile',
      message: hasLinkedIn
          ? 'LinkedIn URL found.'
          : 'No LinkedIn URL found — most recruiters check it before replying.',
      status: hasLinkedIn ? CheckStatus.pass : CheckStatus.warn,
      category: cat1,
    ));
    if (hasGithub) {
      checks.add(const ResumeCheck(
        title: 'GitHub / portfolio link',
        message: 'GitHub link found — great for technical roles.',
        status: CheckStatus.pass,
        category: cat1,
      ));
    }
    checks.add(ResumeCheck(
      title: 'Standard section headers',
      message: sectionsMissing.isEmpty
          ? 'Experience, Education, and Skills sections are all clearly labeled.'
          : 'Missing or unlabeled section(s): ${sectionsMissing.join(', ')}. ATS parsers rely on these exact headers to bucket your content correctly.',
      status: sectionsMissing.isEmpty ? CheckStatus.pass : CheckStatus.fail,
      category: cat1,
    ));

    checks.add(ResumeCheck(
      title: 'Clean text extraction',
      message: runTogetherFound
          ? 'Found words merged together with no spaces — usually caused by tables, columns, or text boxes that don\'t extract cleanly. Real ATS software will see the same jumbled text.'
          : 'Your resume\'s text extracts cleanly — no merged/garbled words detected.',
      status: runTogetherFound ? CheckStatus.fail : CheckStatus.pass,
      category: cat2,
    ));
    checks.add(ResumeCheck(
      title: 'Consistent date formatting',
      message: dateFormatCount > 1
          ? 'You\'re mixing $dateFormatCount different date formats (e.g. "06/2023" and "March 2023"). Pick one style throughout.'
          : 'Date formatting looks consistent.',
      status: dateFormatCount > 1 ? CheckStatus.warn : CheckStatus.pass,
      category: cat2,
    ));
    checks.add(ResumeCheck(
      title: 'Resume length',
      message: pages < 0.6
          ? 'This looks quite short (~${pages.toStringAsFixed(1)} pages). Make sure all relevant experience and projects are included.'
          : pages > 2.3
              ? 'This looks long (~${pages.toStringAsFixed(1)} pages). Recruiters typically spend under 10 seconds on a first pass — consider trimming to 1–2 pages.'
              : 'Length looks appropriate (~${pages.toStringAsFixed(1)} page${pages >= 1.5 ? 's' : ''}).',
      status: (pages < 0.6 || pages > 2.3) ? CheckStatus.warn : CheckStatus.pass,
      category: cat2,
    ));

    final verbPct = contentLineCount == 0 ? 0 : ((strong / contentLineCount) * 100).round();
    checks.add(ResumeCheck(
      title: 'Strong action verbs',
      message: contentLineCount == 0
          ? 'Couldn\'t detect bullet points under Experience/Projects — add some detailed lines describing what you did.'
          : '$verbPct% of your bullets open with a strong action verb (Built, Led, Reduced...).'
              '${weak > 0 ? ' $weak bullet(s) start with a weak phrase like "responsible for" or "worked on" — replace with what you actually did.' : ''}',
      status: contentLineCount == 0
          ? CheckStatus.warn
          : verbPct >= 60
              ? CheckStatus.pass
              : verbPct >= 30
                  ? CheckStatus.warn
                  : CheckStatus.fail,
      category: cat3,
    ));

    final quantPct = contentLineCount == 0 ? 0 : ((quantified / contentLineCount) * 100).round();
    checks.add(ResumeCheck(
      title: 'Quantified achievements',
      message: contentLineCount == 0
          ? 'No bullets detected to check for numbers/metrics.'
          : '$quantPct% of your bullets include a number, %, or metric. Recruiters and ATS scoring both favor quantified impact (e.g. "cut load time by 40%" beats "improved performance").',
      status: contentLineCount == 0
          ? CheckStatus.warn
          : quantPct >= 40
              ? CheckStatus.pass
              : quantPct >= 15
                  ? CheckStatus.warn
                  : CheckStatus.fail,
      category: cat3,
    ));

    checks.add(ResumeCheck(
      title: 'First-person pronouns',
      message: pronounCount == 0
          ? 'No "I / my / me" found — good, resumes should stay in implied first person.'
          : 'Found $pronounCount instance(s) of "I / my / me". Resume bullets should drop the pronoun entirely (e.g. "Led a team of 4" not "I led a team of 4").',
      status: pronounCount == 0
          ? CheckStatus.pass
          : pronounCount <= 3
              ? CheckStatus.warn
              : CheckStatus.fail,
      category: cat4,
    ));
    checks.add(ResumeCheck(
      title: 'Clichés & filler phrases',
      message: clichesFound.isEmpty
          ? 'No overused buzzwords detected.'
          : 'Found generic filler: ${clichesFound.take(4).join(', ')}${clichesFound.length > 4 ? ', …' : ''}. Replace with a specific, provable example instead.',
      status: clichesFound.isEmpty
          ? CheckStatus.pass
          : clichesFound.length <= 2
              ? CheckStatus.warn
              : CheckStatus.fail,
      category: cat4,
    ));

    final passivePct = contentLineCount == 0 ? 0 : ((passiveCount / contentLineCount) * 100).round();
    checks.add(ResumeCheck(
      title: 'Active voice',
      message: contentLineCount == 0
          ? 'No bullets detected to check.'
          : passivePct == 0
              ? 'All bullets are in active voice.'
              : '$passivePct% of bullets read as passive voice (e.g. "was completed by" instead of "completed"). Active voice reads more confident and direct.',
      status: passivePct == 0
          ? CheckStatus.pass
          : passivePct <= 30
              ? CheckStatus.warn
              : CheckStatus.fail,
      category: cat5,
    ));
    checks.add(ResumeCheck(
      title: 'No unnecessary personal details',
      message: personalFound.isEmpty
          ? 'No unnecessary personal fields (DOB, marital status, etc.) found — good, modern resumes leave these out.'
          : 'Found: ${personalFound.join(', ')}. Most ATS systems and recruiters don\'t expect these on a resume — they take up space without helping your case.',
      status: personalFound.isEmpty ? CheckStatus.pass : CheckStatus.warn,
      category: cat5,
    ));

    return checks;
  }
}

class _Segment {
  final String category;
  final List<String> lines;
  const _Segment(this.category, this.lines);
}
