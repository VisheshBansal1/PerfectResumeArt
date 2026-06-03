import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/resume_improve_service.dart';
import '../../../core/services/resume_pdf_service.dart';
import '../../../providers/premium_providers.dart';
import '../../../providers/resume_context_provider.dart';

// ─── Entry Screen ─────────────────────────────────────────────────────────────

class ResumeGeneratorScreen extends ConsumerStatefulWidget {
  final String userEmail;
  final String userName;

  const ResumeGeneratorScreen({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  ConsumerState<ResumeGeneratorScreen> createState() =>
      _ResumeGeneratorScreenState();
}

class _ResumeGeneratorScreenState extends ConsumerState<ResumeGeneratorScreen> {
  int _step = 0;

  // ── Form Controllers ──────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  String _yearsExp = 'Fresher';

  final List<_ExpController> _expControllers = [_ExpController()];
  final _eduCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final List<_ProjController> _projControllers = [_ProjController()];

  static const int _fastTrackStep = 99;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.userEmail;
    _nameCtrl.text = widget.userName;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No unlock check here — build() watches unlockProvider reactively
      final ctx = ref.read(resumeContextProvider);
      if (ctx.hasResume) {
        _prefillFromResume(ctx.text, ctx.detectedRole);
        setState(() => _step = _fastTrackStep);
      }
    });
  }

  // ── Resume data extraction regex helpers ────────────────────────────────
  static final _emailRe = RegExp(r'[\w.%+\-]+@[\w.\-]+\.\w{2,}');
  static final _phoneRe = RegExp(r'(\+?[\d][\d\s\-(). ]{6,}\d)');
  static final _yearRangeRe = RegExp(
    r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s,]+20\d\d',
    caseSensitive: false,
  );
  static final _locationCities = [
    'india',
    'mumbai',
    'delhi',
    'bangalore',
    'bengaluru',
    'hyderabad',
    'pune',
    'chennai',
    'kolkata',
    'ahmedabad',
    'noida',
    'gurugram',
    'gurgaon',
    'chandigarh',
    'jaipur',
    'lucknow',
    'kochi',
  ];

  void _prefillFromResume(String resumeText, String detectedRole) {
    if (detectedRole.isNotEmpty && _roleCtrl.text.isEmpty) {
      _roleCtrl.text = _capitalize(detectedRole);
    }
    final lines = resumeText.split('\n').map((l) => l.trim()).toList();

    // ── 1. Full name — first meaningful non-contact heading ──────────────────
    // Firebase userName may be an alias like "vb" — extract the real name
    // from the resume's first heading line instead.
    final isTrivialName =
        widget.userName.length <= 3 ||
        widget.userName.contains('@') ||
        widget.userName == widget.userName.toLowerCase();
    if (isTrivialName) {
      for (final line in lines.take(12)) {
        if (line.isEmpty) continue;
        if (_emailRe.hasMatch(line)) continue;
        if (_phoneRe.hasMatch(line)) continue;
        if (line.length < 3 || line.length > 60) continue;
        final words = line.split(RegExp(r'\s+'));
        final looksLikeName =
            words.length >= 2 &&
            words.length <= 5 &&
            words.every(
              (w) => w.isNotEmpty && RegExp(r'^[A-Za-z.\-]+$').hasMatch(w),
            );
        if (looksLikeName) {
          _nameCtrl.text = line;
          break;
        }
      }
    }

    // ── 2. Email ─────────────────────────────────────────────────────────────
    for (final line in lines) {
      if (_emailCtrl.text.isEmpty || _emailCtrl.text == widget.userEmail) {
        final m = _emailRe.firstMatch(line);
        if (m != null) {
          _emailCtrl.text = m.group(0)!;
          break;
        }
      }
    }

    // ── 3. Phone ─────────────────────────────────────────────────────────────
    if (_phoneCtrl.text.isEmpty) {
      for (final line in lines) {
        final m = _phoneRe.firstMatch(line);
        if (m != null) {
          final ph = m.group(0)!.trim();
          if (ph.replaceAll(RegExp(r'[^0-9]'), '').length >= 10) {
            _phoneCtrl.text = ph;
            break;
          }
        }
      }
    }

    // ── 4. Location ──────────────────────────────────────────────────────────
    if (_locationCtrl.text.isEmpty) {
      for (final line in lines) {
        final ll = line.toLowerCase();
        if (_locationCities.any((c) => ll.contains(c))) {
          _locationCtrl.text = line.length <= 60 ? line : line.substring(0, 60);
          break;
        }
      }
    }

    // ── 5. Skills — all lines under the skills section ───────────────────────
    if (_skillsCtrl.text.isEmpty) {
      final skillIdx = lines.indexWhere((l) {
        final ll = l.toLowerCase();
        return ll.contains('technical skill') ||
            ll.contains('skills') ||
            ll.contains('technologies') ||
            ll.contains('tech stack');
      });
      if (skillIdx != -1) {
        final nextSecRe = RegExp(
          r'^(education|experience|project|certification|achievement|work|summary|objective)',
          caseSensitive: false,
        );
        final skillLines = <String>[];
        for (int i = skillIdx + 1; i < lines.length && i < skillIdx + 25; i++) {
          final l = lines[i];
          if (l.isEmpty) continue;
          if (nextSecRe.hasMatch(l)) break;
          skillLines.add(l);
        }
        if (skillLines.isNotEmpty) {
          _skillsCtrl.text = skillLines
              .expand((l) => l.contains(':') ? [l.split(':').last.trim()] : [l])
              .where((s) => s.isNotEmpty)
              .join(', ');
        }
      }
    }

    // ── 6. Education ─────────────────────────────────────────────────────────
    if (_eduCtrl.text.isEmpty) {
      final eduIdx = lines.indexWhere((l) {
        final ll = l.toLowerCase();
        return ll == 'education' ||
            ll.startsWith('education') ||
            ll.contains('b.tech') ||
            ll.contains('bachelor') ||
            ll.contains('b.e.') ||
            ll.contains('master') ||
            ll.contains('university') ||
            ll.contains('college');
      });
      if (eduIdx != -1) {
        _eduCtrl.text = lines
            .skip(eduIdx)
            .take(5)
            .where((l) => l.isNotEmpty)
            .join(' | ');
      }
    }

    // ── 7. Work experience — populate experience cards ───────────────────────
    final expIdx = lines.indexWhere((l) {
      final ll = l.toLowerCase();
      return ll.contains('work experience') ||
          ll == 'experience' ||
          ll == 'professional experience' ||
          ll.startsWith('employment history');
    });
    if (expIdx != -1) {
      _expControllers.clear();
      final expHeaderRe = RegExp(r'(.+)\s*[|–\-]\s*(.+)');
      final nextSecRe = RegExp(
        r'^(technical skill|education|project|certification|skill|languages)',
        caseSensitive: false,
      );
      String? currentCompany, currentRole, currentDuration;
      final currentBullets = <String>[];

      void _flushExp() {
        if (currentCompany == null || currentCompany!.isEmpty) return;
        final ctrl = _ExpController();
        ctrl.company.text = currentCompany!;
        ctrl.role.text = currentRole ?? '';
        ctrl.duration.text = currentDuration ?? '';
        ctrl.responsibilities.text = currentBullets.take(5).join('\n');
        _expControllers.add(ctrl);
        currentBullets.clear();
        currentCompany = null;
        currentRole = null;
        currentDuration = null;
      }

      for (int i = expIdx + 1; i < lines.length; i++) {
        final l = lines[i];
        if (l.isEmpty) continue;
        if (nextSecRe.hasMatch(l.toLowerCase())) break;

        final hasDate =
            _yearRangeRe.hasMatch(l) ||
            RegExp(
              r'20\d\d\s*[-–]\s*(20\d\d|present|current)',
              caseSensitive: false,
            ).hasMatch(l);
        final hasBullet =
            l.startsWith('•') ||
            l.startsWith('-') ||
            l.startsWith('*') ||
            RegExp(r'^[A-Z][a-z]+ed ').hasMatch(l) ||
            RegExp(r'^[A-Z][a-z]+ed\b').hasMatch(l);

        if (expHeaderRe.hasMatch(l) && !hasBullet) {
          _flushExp();
          final m = expHeaderRe.firstMatch(l)!;
          final part1 = m.group(1)!.trim();
          final part2 = m.group(2)!.trim();
          if (hasDate) {
            currentCompany = part1;
            currentDuration = part2;
          } else {
            currentCompany = part1;
            currentRole = part2;
          }
        } else if (hasDate &&
            currentCompany != null &&
            currentDuration == null) {
          currentDuration = l;
        } else if (hasBullet && currentCompany != null) {
          final bullet = l.replaceAll(RegExp(r'^[•\-\*]\s*'), '').trim();
          if (bullet.isNotEmpty) currentBullets.add(bullet);
        } else if ((currentRole == null || currentRole!.isEmpty) &&
            currentCompany != null &&
            !hasDate &&
            !hasBullet) {
          currentRole = l;
        }
      }
      _flushExp();
      if (_expControllers.isEmpty) _expControllers.add(_ExpController());
    }

    setState(() {});
  }

  String _capitalize(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _roleCtrl.dispose();
    _eduCtrl.dispose();
    _skillsCtrl.dispose();
    for (final c in _expControllers) c.dispose();
    for (final c in _projControllers) c.dispose();
    super.dispose();
  }

  void _generate() {
    final state = ref.read(resumeGeneratorProvider);
    if (state.isLoading) return;
    final ctx = ref.read(resumeContextProvider);
    ref
        .read(resumeGeneratorProvider.notifier)
        .generate(
          fullName: _nameCtrl.text.trim().isNotEmpty
              ? _nameCtrl.text.trim()
              : widget.userName,
          email: _emailCtrl.text.trim().isNotEmpty
              ? _emailCtrl.text.trim()
              : widget.userEmail,
          phone: _phoneCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          targetRole: _roleCtrl.text.trim(),
          yearsExp: _yearsExp,
          experiences: _expControllers
              .where((e) => e.company.text.isNotEmpty)
              .map(
                (e) => ExperienceEntry(
                  company: e.company.text.trim(),
                  role: e.role.text.trim(),
                  duration: e.duration.text.trim(),
                  responsibilities: e.responsibilities.text.trim(),
                ),
              )
              .toList(),
          education: _eduCtrl.text.trim(),
          skills: _skillsCtrl.text.trim(),
          projects: _projControllers
              .where((p) => p.name.text.isNotEmpty)
              .map(
                (p) => ProjectEntry(
                  name: p.name.text.trim(),
                  techStack: p.techStack.text.trim(),
                  description: p.desc.text.trim(),
                ),
              )
              .toList(),
          existingResumeText: ctx.hasResume ? ctx.text : '',
        );
    setState(() => _step = 3);
  }

  Future<void> _handleUnlock() async {
    final paid = await PaywallSheet.show(
      context,
      plan: PaymentPlan.resumeGenerator,
      userEmail: widget.userEmail,
      userName: widget.userName,
    );
    if (paid && mounted) {
      await ref.read(unlockProvider.notifier).unlock('resume_generator');
      if (_step == _fastTrackStep && _roleCtrl.text.trim().isNotEmpty) {
        _generate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final genState = ref.watch(resumeGeneratorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Watch reactively — unlocked becomes true the moment Firestore loads or
    // user purchases, without needing a local bool that races async Firestore.
    final _unlockSet = ref.watch(unlockProvider);
    final unlocked =
        _unlockSet.contains('resume_generator') ||
        _unlockSet.contains('bundle');

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('AI Resume Builder'),
        actions: [
          if (unlocked && genState.result != null)
            _DownloadButton(name: _nameCtrl.text),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _body(genState, isDark, unlocked),
      ),
    );
  }

  Widget _body(ResumeGeneratorState state, bool isDark, bool unlocked) {
    if (_step == _fastTrackStep) return _fastTrackView(state, isDark, unlocked);

    if (_step == 3) {
      if (state.isLoading) return _LoadingView();
      if (state.error != null)
        return _ErrorView(error: state.error!, onRetry: _generate);
      if (state.result != null) {
        return _PreviewView(
          result: state.result!,
          unlocked: unlocked,
          onUnlock: _handleUnlock,
          userName: _nameCtrl.text,
        );
      }
    }

    return Column(
      children: [
        _StepIndicator(step: _step),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: [
              _step0_personal(isDark),
              _step1_experience(isDark),
              _step2_education(isDark),
            ][_step.clamp(0, 2)],
          ),
        ),
        _FormNav(
          step: _step,
          canNext: _canProceed(),
          onBack: () => setState(() => _step--),
          onNext: () {
            if (_step < 2)
              setState(() => _step++);
            else
              _generate();
          },
        ),
      ],
    );
  }

  Widget _fastTrackView(
    ResumeGeneratorState state,
    bool isDark,
    bool unlocked,
  ) {
    if (state.isLoading) return _LoadingView();
    if (state.error != null)
      return _ErrorView(error: state.error!, onRetry: _generate);
    if (state.result != null) {
      return _PreviewView(
        result: state.result!,
        unlocked: unlocked,
        onUnlock: _handleUnlock,
        userName: _nameCtrl.text,
      );
    }

    final ctx = ref.read(resumeContextProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resume detected banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resume Detected ✅',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.success,
                        ),
                      ),
                      Text(
                        'AI will extract all your info and score your current resume, then build a better one.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'What role are you targeting?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'AI will tailor your resume and show you your before/after ATS score',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _roleCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText:
                  'e.g. Flutter Developer, Data Analyst, Backend Engineer',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              prefixIcon: const Icon(Icons.work_outline, size: 18),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                      ctx.detectedRole.isNotEmpty
                          ? ctx.detectedRole
                          : 'Flutter Developer',
                      'Android Developer',
                      'Backend Developer',
                      'Full Stack Developer',
                      'Data Analyst',
                      'Product Manager',
                    ]
                    .map(
                      (r) => GestureDetector(
                        onTap: () =>
                            setState(() => _roleCtrl.text = _capitalize(r)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _roleCtrl.text.toLowerCase() == r.toLowerCase()
                                ? AppTheme.primary.withOpacity(0.15)
                                : (isDark
                                      ? const Color(0xFF1E2030)
                                      : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  _roleCtrl.text.toLowerCase() ==
                                      r.toLowerCase()
                                  ? AppTheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            r,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  _roleCtrl.text.toLowerCase() ==
                                      r.toLowerCase()
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _roleCtrl.text.trim().isEmpty
                  ? null
                  : () {
                      if (unlocked)
                        _generate();
                      else
                        _handleUnlock();
                    },
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: Text(
                unlocked
                    ? 'Generate My Resume  →'
                    : 'Unlock & Generate  ·  ₹49',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text(
                'Fill manually instead',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    if (_step == 0)
      return _nameCtrl.text.isNotEmpty && _roleCtrl.text.isNotEmpty;
    return true;
  }

  // ── Step 0: Personal Info ─────────────────────────────────────────────────
  Widget _step0_personal(bool isDark) {
    final ctx = ref.read(resumeContextProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ctx.hasResume) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.success, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resume detected! Form pre-filled. Review and edit as needed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        _SectionLabel('Personal Information'),
        _Field(_nameCtrl, 'Full Name *', hint: 'Vishesh Sharma'),
        _Field(
          _emailCtrl,
          'Email *',
          hint: 'vishesh@gmail.com',
          keyboardType: TextInputType.emailAddress,
        ),
        _Field(
          _phoneCtrl,
          'Phone',
          hint: '+91 98765 43210',
          keyboardType: TextInputType.phone,
        ),
        _Field(_locationCtrl, 'Location', hint: 'Mumbai, India'),
        _Field(
          _roleCtrl,
          'Target Role *',
          hint: 'Flutter Developer / Data Scientist',
        ),
        const SizedBox(height: 16),
        const Text(
          'Years of Experience',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Fresher', '1-2 yrs', '3-5 yrs', '5-8 yrs', '8+ yrs']
              .map(
                (y) => GestureDetector(
                  onTap: () => setState(() => _yearsExp = y),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _yearsExp == y
                          ? AppTheme.primary
                          : (isDark ? const Color(0xFF1A1D27) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _yearsExp == y
                            ? AppTheme.primary
                            : (isDark
                                  ? Colors.white24
                                  : const Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: Text(
                      y,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _yearsExp == y ? Colors.white : null,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ── Step 1: Work Experience ───────────────────────────────────────────────
  Widget _step1_experience(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Work Experience'),
        Text(
          "Don't worry if you're a fresher — add internships or skip this.",
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        ..._expControllers.asMap().entries.map(
          (e) => _ExpCard(
            index: e.key + 1,
            ctrl: e.value,
            isDark: isDark,
            onRemove: _expControllers.length > 1
                ? () => setState(() => _expControllers.removeAt(e.key))
                : null,
          ),
        ),
        if (_expControllers.length < 3)
          TextButton.icon(
            onPressed: () =>
                setState(() => _expControllers.add(_ExpController())),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add Another Experience'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          ),
      ],
    );
  }

  // ── Step 2: Education + Skills + Projects ─────────────────────────────────
  Widget _step2_education(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Education'),
        _Field(
          _eduCtrl,
          'Degree, College, Year',
          hint: 'B.Tech Computer Science, IIT Delhi, 2024 | CGPA: 8.2',
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        _SectionLabel('Technical Skills'),
        _Field(
          _skillsCtrl,
          'Skills (comma separated)',
          hint: 'Flutter, Dart, Firebase, Python, Node.js, React, SQL, Git',
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        _SectionLabel('Projects (Optional but highly recommended)'),
        ..._projControllers.asMap().entries.map(
          (e) => _ProjCard(
            index: e.key + 1,
            ctrl: e.value,
            isDark: isDark,
            onRemove: _projControllers.length > 1
                ? () => setState(() => _projControllers.removeAt(e.key))
                : null,
          ),
        ),
        if (_projControllers.length < 3)
          TextButton.icon(
            onPressed: () =>
                setState(() => _projControllers.add(_ProjController())),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add Another Project'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates, color: AppTheme.primary, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The more details you provide, the better your ATS score. '
                  'Even rough notes work — AI will polish and quantify everything.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Preview Screen ───────────────────────────────────────────────────────────

class _PreviewView extends ConsumerWidget {
  final GeneratedResume result;
  final bool unlocked;
  final VoidCallback onUnlock;
  final String userName;

  const _PreviewView({
    required this.result,
    required this.unlocked,
    required this.onUnlock,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Before / After Score Banner ──────────────────────────────
          if (result.hadExistingResume) ...[
            _BeforeAfterBanner(
              scoreBefore: result.atsScoreBefore,
              scoreAfter: result.atsScoreAfter,
            ),
            const SizedBox(height: 16),
          ] else ...[
            _GenAtsCard(score: result.atsScoreAfter),
            const SizedBox(height: 16),
          ],

          // ── 2. Section Score Breakdown ───────────────────────────────────
          if (result.sectionScores.isNotEmpty) ...[
            _SectionScoreCard(scores: result.sectionScores, isDark: isDark),
            const SizedBox(height: 16),
          ],

          // ── 3. Missing Items — What to Add ───────────────────────────────
          if (result.missingItems.isNotEmpty) ...[
            _MissingItemsCard(items: result.missingItems, isDark: isDark),
            const SizedBox(height: 16),
          ],

          // ── 4. Key Strengths ─────────────────────────────────────────────
          if (result.keyStrengths.isNotEmpty) ...[
            const Text(
              'Key Strengths Identified:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...result.keyStrengths.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.star, color: AppTheme.warning, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 5. Resume Preview ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D27) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Your AI-Generated Resume',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (unlocked)
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: result.resumeText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Copied!')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('Copy'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: unlocked
                      ? SelectableText(
                          result.resumeText,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.8,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                          ),
                        )
                      : _BlurredResume(text: result.resumeText, isDark: isDark),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 6. Improvement Tips ──────────────────────────────────────────
          if (result.improvementTips.isNotEmpty) ...[
            _ImprovementTipsCard(tips: result.improvementTips),
            const SizedBox(height: 16),
          ],

          // ── 7. Unlock card OR bonus content ─────────────────────────────
          if (!unlocked)
            _UnlockCard(onUnlock: onUnlock)
          else ...[
            if (result.suggestedRoles.isNotEmpty) ...[
              const Text(
                'Best Suited Roles for You:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.suggestedRoles
                    .map(
                      (r) => Chip(
                        label: Text(
                          r,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        side: BorderSide(
                          color: AppTheme.primary.withOpacity(0.3),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            if (result.topKeywords.isNotEmpty) ...[
              const Text(
                'Top 12 ATS Keywords for Your Role:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: result.topKeywords
                    .map(
                      (k) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.success.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          k,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            if (result.linkedinSummary.isNotEmpty)
              _LinkedinCard(summary: result.linkedinSummary),
          ],
        ],
      ),
    );
  }
}

// ─── Before / After Banner ────────────────────────────────────────────────────

class _BeforeAfterBanner extends StatefulWidget {
  final int scoreBefore;
  final int scoreAfter;
  const _BeforeAfterBanner({
    required this.scoreBefore,
    required this.scoreAfter,
  });

  @override
  State<_BeforeAfterBanner> createState() => _BeforeAfterBannerState();
}

class _BeforeAfterBannerState extends State<_BeforeAfterBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _colorFor(int s) => s >= 80
      ? AppTheme.success
      : s >= 60
      ? AppTheme.warning
      : AppTheme.error;
  String _labelFor(int s) {
    if (s >= 85) return '🏆 Excellent';
    if (s >= 75) return '✅ Strong';
    if (s >= 60) return '⚠️ Average';
    if (s >= 45) return '❌ Weak';
    return '🚨 Very Low';
  }

  @override
  Widget build(BuildContext context) {
    final improvement = widget.scoreAfter - widget.scoreBefore;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.compare_arrows,
                size: 18,
                color: AppTheme.success,
              ),
              const SizedBox(width: 8),
              const Text(
                'ATS Score: Before vs After',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+$improvement pts',
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Before row
          _ScoreRow(
            label: 'Your Old Resume',
            score: widget.scoreBefore,
            maxScore: 100,
            anim: _anim,
            color: _colorFor(widget.scoreBefore),
            badge: _labelFor(widget.scoreBefore),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // After row
          _ScoreRow(
            label: 'Your New Resume',
            score: widget.scoreAfter,
            maxScore: 100,
            anim: _anim,
            color: _colorFor(widget.scoreAfter),
            badge: _labelFor(widget.scoreAfter),
            isDark: isDark,
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;
  final Animation<double> anim;
  final Color color;
  final String badge;
  final bool isDark;
  final bool highlight;

  const _ScoreRow({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.anim,
    required this.color,
    required this.badge,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: highlight ? color : AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: anim,
              builder: (_, __) => Text(
                '${(score * anim.value).round()} / $maxScore',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: anim,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / maxScore * anim.value,
              minHeight: highlight ? 12 : 8,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          badge,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Section Score Breakdown ──────────────────────────────────────────────────

class _SectionScoreCard extends StatelessWidget {
  final List<AtsSectionScore> scores;
  final bool isDark;
  const _SectionScoreCard({required this.scores, required this.isDark});

  Color _colorFor(AtsSectionScore s) {
    if (s.pct >= 0.9) return AppTheme.success;
    if (s.pct >= 0.7) return const Color(0xFF22C55E);
    if (s.pct >= 0.5) return AppTheme.warning;
    return AppTheme.error;
  }

  String _icon(String category) {
    switch (category) {
      case 'Power Action Verbs':
        return '⚡';
      case 'Quantified Achievements':
        return '📊';
      case 'Role Keywords':
        return '🔑';
      case 'ATS Structure':
        return '📋';
      case 'Contact Info':
        return '📱';
      case 'Summary Quality':
        return '✍️';
      default:
        return '📌';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, size: 18, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'ATS Score Breakdown',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap each category to see what to fix',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          ...scores.map(
            (s) => _SectionScoreRow(
              s: s,
              color: _colorFor(s),
              icon: _icon(s.category),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionScoreRow extends StatefulWidget {
  final AtsSectionScore s;
  final Color color;
  final String icon;
  const _SectionScoreRow({
    required this.s,
    required this.color,
    required this.icon,
  });

  @override
  State<_SectionScoreRow> createState() => _SectionScoreRowState();
}

class _SectionScoreRowState extends State<_SectionScoreRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 200 + widget.s.maxScore * 10), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _anim,
                  builder: (_, __) => Text(
                    '${(s.score * _anim.value).round()}/${s.maxScore}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.color,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.verdict,
                    style: TextStyle(
                      fontSize: 10,
                      color: widget.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: s.score / s.maxScore * _anim.value,
                  minHeight: 7,
                  backgroundColor: widget.color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                ),
              ),
            ),
            // Expandable tip
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _expanded && s.tip.isNotEmpty
                  ? Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.color.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 13,
                            color: widget.color,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.tip,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                color: widget.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Missing Items Card ───────────────────────────────────────────────────────

class _MissingItemsCard extends StatelessWidget {
  final List<MissingItem> items;
  final bool isDark;
  const _MissingItemsCard({required this.items, required this.isDark});

  Color _priorityColor(String p) {
    switch (p) {
      case 'critical':
        return AppTheme.error;
      case 'high':
        return AppTheme.warning;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints = items.fold<int>(0, (sum, i) => sum + i.pointsToGain);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.add_circle_outline,
                size: 18,
                color: AppTheme.warning,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'What to Add to Score Higher',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+$totalPoints pts available',
                  style: const TextStyle(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Add these items to your resume and re-generate for a higher score',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => _MissingItemRow(
              item: item,
              color: _priorityColor(item.priority),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingItemRow extends StatefulWidget {
  final MissingItem item;
  final Color color;
  const _MissingItemRow({required this.item, required this.color});

  @override
  State<_MissingItemRow> createState() => _MissingItemRowState();
}

class _MissingItemRowState extends State<_MissingItemRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(item.priorityEmoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.item,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${item.pointsToGain} pts',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            if (item.section.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Add to: ${item.section}',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _expanded
                  ? Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.east, size: 12, color: widget.color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.howToAdd,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                color: widget.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Improvement Tips Card ────────────────────────────────────────────────────

class _ImprovementTipsCard extends StatelessWidget {
  final List<String> tips;
  const _ImprovementTipsCard({required this.tips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates, color: Color(0xFFFFB300), size: 16),
              SizedBox(width: 6),
              Text(
                'Push Your Score to 90+:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF7B5800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7B5800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LinkedIn Card ────────────────────────────────────────────────────────────

class _LinkedinCard extends StatelessWidget {
  final String summary;
  const _LinkedinCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0077B5).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0077B5).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link, color: Color(0xFF0077B5), size: 16),
              SizedBox(width: 6),
              Text(
                'LinkedIn "About" Section',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0077B5),
                ),
              ),
              Spacer(),
              Text(
                'Bonus ✨',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0077B5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            summary,
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: summary));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ LinkedIn summary copied!')),
              );
            },
            child: const Row(
              children: [
                Icon(Icons.copy, size: 13, color: Color(0xFF0077B5)),
                SizedBox(width: 4),
                Text(
                  'Copy',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0077B5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Blurred resume preview ───────────────────────────────────────────────────

class _BlurredResume extends StatelessWidget {
  final String text;
  final bool isDark;
  const _BlurredResume({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final showLines = (lines.length * 0.35).round().clamp(5, 20);
    final visible = lines.take(showLines).join('\n');
    final blurred = lines.skip(showLines).join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          visible,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.8,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        Stack(
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Text(
                blurred,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.8,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            Colors.transparent,
                            const Color(0xFF1A1D27).withOpacity(0.7),
                          ]
                        : [Colors.transparent, Colors.white.withOpacity(0.7)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Unlock Card ─────────────────────────────────────────────────────────────

class _UnlockCard extends StatelessWidget {
  final VoidCallback onUnlock;
  const _UnlockCard({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D5BE3), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D5BE3).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔒 Unlock Your Full Resume',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get the complete resume + PDF download + ATS keywords + LinkedIn summary + full score breakdown',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
          ...[
            '📄 Complete formatted resume (copy & download)',
            '⬇️ PDF download (ATS-friendly, clean formatting)',
            '📊 Full section-by-section score breakdown',
            '📋 Missing items list with exact point values',
            '🔑 Top 12 ATS keywords for your target role',
            '💼 4 best-fit job titles for your background',
            '🔗 LinkedIn "About" section (180-word bonus)',
          ].map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    f,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUnlock,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2D5BE3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Unlock Full Resume · ₹49',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ATS Score Card (no existing resume) ─────────────────────────────────────

class _GenAtsCard extends StatefulWidget {
  final int score;
  const _GenAtsCard({required this.score});
  @override
  State<_GenAtsCard> createState() => _GenAtsCardState();
}

class _GenAtsCardState extends State<_GenAtsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _color => widget.score >= 80
      ? AppTheme.success
      : widget.score >= 65
      ? AppTheme.warning
      : AppTheme.error;
  String get _label {
    if (widget.score >= 85) return '🏆 Excellent — Will pass most ATS filters';
    if (widget.score >= 75)
      return '✅ Strong — Good chance of getting shortlisted';
    if (widget.score >= 60)
      return '⚠️ Average — Needs improvement to stand out';
    if (widget.score >= 45) return '❌ Weak — Many jobs will filter this out';
    return '🚨 Very Low — Requires major improvements';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, size: 18, color: AppTheme.success),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ATS Score of Your New Resume',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(widget.score * _anim.value).round()} / 100',
                    style: TextStyle(
                      color: _color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: widget.score / 100 * _anim.value,
                    minHeight: 14,
                    backgroundColor: _color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(_color),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading View ─────────────────────────────────────────────────────────────

class _LoadingView extends StatefulWidget {
  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _msgIdx = 0;

  final _msgs = [
    'Scoring your existing resume…',
    'Extracting all your real data…',
    'Writing power-verb bullet points…',
    'Adding realistic metrics to bullets…',
    'Embedding ATS keywords for your role…',
    'Building section-by-section score…',
    'Identifying what to add for +points…',
    'Writing your LinkedIn summary…',
    'Final polish — almost ready ✨',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl);
    Future.delayed(const Duration(seconds: 3), _cycle);
  }

  void _cycle() {
    if (!mounted) return;
    setState(() => _msgIdx = (_msgIdx + 1) % _msgs.length);
    Future.delayed(const Duration(seconds: 3), _cycle);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _anim,
              child: const Text('✨', style: TextStyle(fontSize: 56)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Building your perfect resume…',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _msgs[_msgIdx],
                key: ValueKey(_msgIdx),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'This takes 15–30 seconds',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Download Button ──────────────────────────────────────────────────────────

class _DownloadButton extends ConsumerWidget {
  final String name;
  const _DownloadButton({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resumeGeneratorProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: state.isGeneratingPdf
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download PDF',
              onPressed: () async {
                await ref
                    .read(resumeGeneratorProvider.notifier)
                    .generatePdf(name: name);
                final path = ref.read(resumeGeneratorProvider).pdfPath;
                if (path != null && context.mounted) {
                  ResumePdfService().sharePdf(path);
                }
              },
            ),
    );
  }
}

// ─── Form Helpers ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = ['Personal', 'Experience', 'Education'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: steps.asMap().entries.map((e) {
          final active = e.key == step;
          final done = e.key < step;
          final color = active || done
              ? AppTheme.primary
              : AppTheme.textSecondary;
          return Expanded(
            child: Row(
              children: [
                if (e.key > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done
                          ? AppTheme.primary
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: active || done
                            ? AppTheme.primary
                            : Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : Text(
                                '${e.key + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active ? Colors.white : Colors.grey,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (e.key < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done
                          ? AppTheme.primary
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FormNav extends StatelessWidget {
  final int step;
  final bool canNext;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _FormNav({
    required this.step,
    required this.canNext,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = step == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canNext ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isLast ? '✨ Generate My Resume' : 'Continue',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  const _Field(
    this.ctrl,
    this.label, {
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    ),
  );
}

class _ExpController {
  final company = TextEditingController();
  final role = TextEditingController();
  final duration = TextEditingController();
  final responsibilities = TextEditingController();
  void dispose() {
    company.dispose();
    role.dispose();
    duration.dispose();
    responsibilities.dispose();
  }
}

class _ExpCard extends StatelessWidget {
  final int index;
  final _ExpController ctrl;
  final bool isDark;
  final VoidCallback? onRemove;
  const _ExpCard({
    required this.index,
    required this.ctrl,
    required this.isDark,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Experience $index',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.primary,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(ctrl.company, 'Company Name', hint: 'Google / Startup XYZ'),
          _Field(ctrl.role, 'Your Role', hint: 'Software Engineer Intern'),
          _Field(ctrl.duration, 'Duration', hint: 'Jan 2023 - Jun 2023'),
          _Field(
            ctrl.responsibilities,
            'What you did (rough notes OK)',
            hint: 'Built a dashboard, worked on API, reduced loading time',
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

class _ProjController {
  final name = TextEditingController();
  final techStack = TextEditingController();
  final desc = TextEditingController();
  void dispose() {
    name.dispose();
    techStack.dispose();
    desc.dispose();
  }
}

class _ProjCard extends StatelessWidget {
  final int index;
  final _ProjController ctrl;
  final bool isDark;
  final VoidCallback? onRemove;
  const _ProjCard({
    required this.index,
    required this.ctrl,
    required this.isDark,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Project $index',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(
            ctrl.name,
            'Project Name',
            hint: 'E-commerce App / ML Classifier',
          ),
          _Field(
            ctrl.techStack,
            'Tech Stack Used',
            hint: 'Flutter, Firebase, Python, TensorFlow',
          ),
          _Field(
            ctrl.desc,
            'Brief Description',
            hint: 'What it does, how many users, what problem it solves',
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
