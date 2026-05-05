import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:next_hire/features/resume/screens/upload_resume_screen.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';
import '../../../providers/premium_providers.dart';
import '../../../features/premium/screens/premium_hub_screen.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _scoreColor(int score) {
  if (score >= AppConstants.excellentScore) return AppTheme.success;
  if (score >= AppConstants.goodScore) return AppTheme.primary;
  if (score >= AppConstants.averageScore) return AppTheme.warning;
  return AppTheme.error;
}

String _scoreLabel(int score) {
  if (score >= AppConstants.excellentScore) return 'Excellent';
  if (score >= AppConstants.goodScore) return 'Good';
  if (score >= AppConstants.averageScore) return 'Fair';
  return 'Needs Work';
}

// ─── Screen ────────────────────────────────────────────────────────────────────

class AnalysisResultScreen extends ConsumerWidget {
  final String analysisId;
  const AnalysisResultScreen({super.key, required this.analysisId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisProvider(analysisId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Result'),
        actions: [
          analysis.whenOrNull(
                data: (a) => a != null
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _TypeBadge(a.analysisType),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: analysis.when(
        data: (a) => a == null
            ? const Center(child: Text('Analysis not found'))
            : _AnalysisBody(analysis: a),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error loading analysis: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Body ──────────────────────────────────────────────────────────────────────

class _AnalysisBody extends StatelessWidget {
  final AnalysisModel analysis;
  const _AnalysisBody({required this.analysis});

  bool get _isAtsOnly => analysis.analysisType == 'ats_only';
  bool get _isCustom => analysis.analysisType == 'custom_tech';
  bool get _isNotResume => analysis.finalRecommendation == 'Not a Resume';

  @override
  Widget build(BuildContext context) {
    if (_isNotResume) return _NotResumeState(analysis: analysis);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero score header
          _HeroHeader(analysis: analysis),
          const SizedBox(height: 16),

          // ── Score breakdown cards
          _ScoreGrid(analysis: analysis),
          const SizedBox(height: 16),

          // ── AI / ATS recommendation banner
          _RecommendationBanner(analysis: analysis),
          const SizedBox(height: 16),

          // ── ATS-only contextual info + dimension guide
          if (_isAtsOnly) ...[
            _AtsContextCard(analysis: analysis),
            const SizedBox(height: 16),
          ],

          // ── Custom tech contextual info
          if (_isCustom) ...[
            _CustomTechContextCard(analysis: analysis),
            const SizedBox(height: 16),
          ],

          // ── Strengths
          if (analysis.strengths.isNotEmpty) ...[
            _SectionBlock(
              title: 'Strengths',
              icon: Icons.thumb_up_alt_outlined,
              color: AppTheme.success,
              items: analysis.strengths,
            ),
            const SizedBox(height: 16),
          ],

          // ── Weaknesses
          if (analysis.weaknesses.isNotEmpty) ...[
            _SectionBlock(
              title: 'Areas to Improve',
              icon: Icons.trending_up_rounded,
              color: AppTheme.warning,
              items: analysis.weaknesses,
            ),
            const SizedBox(height: 16),
          ],

          // ── Missing skills / elements
          if (analysis.missingSkills.isNotEmpty) ...[
            _MissingSection(analysis: analysis),
            const SizedBox(height: 16),
          ],

          // ── Project analysis
          if (analysis.projects.isNotEmpty) ...[
            _ProjectsSection(projects: analysis.projects),
            const SizedBox(height: 16),
          ],

          // ── Improvement suggestions
          if (analysis.suggestions.isNotEmpty) ...[
            _SuggestionsSection(suggestions: analysis.suggestions),
            const SizedBox(height: 16),
          ],

          // ── Admin decision (if present)
          if (analysis.adminDecision != null)
            _AdminDecisionCard(analysis: analysis),

          // ── Premium upgrade CTA
          const SizedBox(height: 20),
          _PremiumCta(analysis: analysis),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

Color _recommendationColor(String rec) {
  switch (rec) {
    case 'High Potential':
      return AppTheme.primary;
    case 'Pass':
      return AppTheme.success;
    case 'Not a Resume':
      return Colors.grey.shade600;
    default:
      return AppTheme.error;
  }
}

IconData _recommendationIcon(String rec) {
  switch (rec) {
    case 'High Potential':
      return Icons.star_rounded;
    case 'Pass':
      return Icons.check_circle_rounded;
    case 'Not a Resume':
      return Icons.description_outlined;
    default:
      return Icons.cancel_rounded;
  }
}

// ─── Not a Resume State ────────────────────────────────────────────────────────

class _NotResumeState extends StatelessWidget {
  final AnalysisModel analysis;
  const _NotResumeState({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.find_in_page_outlined,
                size: 44,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Not a Resume',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'The uploaded file doesn\'t appear to be a resume or CV. '
              'Our AI couldn\'t detect the standard sections needed for analysis '
              '(name, contact info, experience, education, or skills).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What to check:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...[
                    'Make sure the file is your actual resume or CV',
                    'Accepted formats: PDF, JPG, PNG',
                    'If it\'s an image, ensure the text is clearly readable',
                    'Scanned documents may have low OCR accuracy — try a PDF version',
                    'The file must contain your name, experience, and skills',
                  ].map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.arrow_right_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => UploadResumeScreen()),
                ),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload a Different File'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero Header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final AnalysisModel analysis;
  const _HeroHeader({required this.analysis});

  bool get _isAtsOnly => analysis.analysisType == 'ats_only';
  bool get _isCustom => analysis.analysisType == 'custom_tech';

  Color get _accentColor {
    if (_isAtsOnly) return Colors.purple;
    if (_isCustom) return AppTheme.accent;
    return AppTheme.primary;
  }

  String get _subtitle {
    if (_isAtsOnly) return 'ATS Compatibility Check';
    if (_isCustom) return 'Custom Tech Stack Analysis';
    return 'Job Match Analysis';
  }

  @override
  Widget build(BuildContext context) {
    final scoreCol = _scoreColor(analysis.overallScore);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: title + date + subtitle badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.jobTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat(
                        'MMM d, yyyy • h:mm a',
                      ).format(analysis.analyzedAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: _accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right: animated score ring
          Column(
            children: [
              _CircleScore(score: analysis.overallScore, size: 76),
              const SizedBox(height: 4),
              Text(
                _scoreLabel(analysis.overallScore),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scoreCol,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Score Grid ────────────────────────────────────────────────────────────────

class _ScoreGrid extends StatelessWidget {
  final AnalysisModel analysis;
  const _ScoreGrid({required this.analysis});

  bool get _isAtsOnly => analysis.analysisType == 'ats_only';

  @override
  Widget build(BuildContext context) {
    if (_isAtsOnly) {
      return Row(
        children: [
          Expanded(
            child: _ScoreCard(
              label: 'ATS Score',
              score: analysis.atsScore,
              color: Colors.purple,
              icon: Icons.fact_check_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ScoreCard(
              label: 'Projects',
              score: analysis.projectScore,
              color: AppTheme.accent,
              icon: Icons.code_outlined,
            ),
          ),
        ],
      );
    }

    // Full / custom_tech — 3 cards
    return Row(
      children: [
        Expanded(
          child: _ScoreCard(
            label: analysis.analysisType == 'custom_tech'
                ? 'Stack Match'
                : 'Job Match',
            score: analysis.matchScore,
            color: AppTheme.primary,
            icon: Icons.analytics_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScoreCard(
            label: 'ATS',
            score: analysis.atsScore,
            color: Colors.purple,
            icon: Icons.fact_check_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScoreCard(
            label: 'Projects',
            score: analysis.projectScore,
            color: AppTheme.accent,
            icon: Icons.code_outlined,
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final IconData icon;

  const _ScoreCard({
    required this.label,
    required this.score,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color.withOpacity(0.8)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _scoreLabel(score),
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recommendation Banner ─────────────────────────────────────────────────────

class _RecommendationBanner extends StatelessWidget {
  final AnalysisModel analysis;
  const _RecommendationBanner({required this.analysis});

  bool get _isAtsOnly => analysis.analysisType == 'ats_only';

  String get _heading => _isAtsOnly ? 'ATS Rating' : 'AI Recommendation';

  String get _description {
    final rec = analysis.finalRecommendation;
    final score = analysis.overallScore;
    switch (rec) {
      case 'High Potential':
        return 'Outstanding resume — $score% overall. Strong skill coverage '
            'with impressive project depth. Highly competitive candidate.';
      case 'Pass':
        return 'Solid resume — $score% overall. Meets the key requirements '
            'with room for improvement in a few areas.';
      default:
        return 'Resume scored $score% overall. Several important gaps need '
            'to be addressed before this application is competitive.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = analysis.finalRecommendation;
    final color = _recommendationColor(rec);
    final icon = _recommendationIcon(rec);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _heading,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rec,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.45,
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

// ─── ATS Context Card ──────────────────────────────────────────────────────────

class _AtsContextCard extends StatelessWidget {
  final AnalysisModel analysis;
  const _AtsContextCard({required this.analysis});

  // Dynamic interpretation of the ATS score
  String get _atsInterpretation {
    final s = analysis.atsScore;
    if (s >= 80) {
      return 'Your resume is highly ATS-friendly. It will likely rank in the '
          'top tier for most automated filtering systems.';
    }
    if (s >= 65) {
      return 'Your resume passes most ATS filters but has some formatting or '
          'keyword gaps that could reduce your ranking in competitive pools.';
    }
    if (s >= 50) {
      return 'Your resume has a moderate ATS compatibility. Some structural '
          'or keyword issues may cause it to rank lower or be filtered out '
          'before a human reviewer sees it.';
    }
    return 'Your resume is at high risk of automated rejection. Critical '
        'structural issues or missing keywords are preventing it from '
        'ranking well in ATS systems like Workday, Greenhouse, or Lever.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.purple.shade600, size: 16),
              const SizedBox(width: 8),
              const Text(
                'ATS Scoring Explained',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _atsInterpretation,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const _AtsDimensionGuide(),
        ],
      ),
    );
  }
}

class _AtsDimensionGuide extends StatelessWidget {
  const _AtsDimensionGuide();

  @override
  Widget build(BuildContext context) {
    const dimensions = [
      (
        Icons.format_align_left_outlined,
        'Parseability (30%)',
        'Clean sections, standard headers, no tables or text-boxes',
      ),
      (
        Icons.key_outlined,
        'Keyword Density (25%)',
        'Relevant terms used naturally, both full names and abbreviations',
      ),
      (
        Icons.bar_chart_outlined,
        'Quantified Impact (25%)',
        '40%+ bullets should include numbers, metrics, or percentages',
      ),
      (
        Icons.view_agenda_outlined,
        'Structure & Length (20%)',
        'Consistent font hierarchy, correct page length for experience level',
      ),
    ];

    return Column(
      children: dimensions.map((d) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(d.$1, size: 14, color: Colors.purple.shade600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple,
                      ),
                    ),
                    Text(
                      d.$3,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Custom Tech Context Card ──────────────────────────────────────────────────

class _CustomTechContextCard extends StatelessWidget {
  final AnalysisModel analysis;
  const _CustomTechContextCard({required this.analysis});

  String get _interpretation {
    final s = analysis.matchScore;
    if (s >= 80) {
      return 'Excellent stack coverage — your resume strongly demonstrates '
          'proficiency in the required technologies, both directly and '
          'through inferred experience from related projects.';
    }
    if (s >= 55) {
      return 'Good stack coverage — you meet the core requirements but '
          'have some gaps in the required tech stack. Targeted projects '
          'or courses could quickly close these gaps.';
    }
    return 'Partial stack coverage — your resume shows experience with '
        'some of the required technologies but misses several key areas. '
        'Building focused projects will significantly improve this score.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.accent.withOpacity(0.8),
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _interpretation,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Block (Strengths / Weaknesses) ────────────────────────────────────

class _SectionBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _SectionBlock({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, icon: icon, color: color),
        const SizedBox(height: 10),
        ...items.asMap().entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Missing Skills / Elements Section ────────────────────────────────────────

class _MissingSection extends StatelessWidget {
  final AnalysisModel analysis;
  const _MissingSection({required this.analysis});

  bool get _isAtsOnly => analysis.analysisType == 'ats_only';

  @override
  Widget build(BuildContext context) {
    final label = _isAtsOnly ? 'Missing Elements' : 'Missing Skills';
    final items = analysis.missingSkills;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: label,
          icon: Icons.warning_amber_rounded,
          color: AppTheme.warning,
        ),
        const SizedBox(height: 10),
        // Use list rows instead of chips — AI returns long explanatory strings
        ...items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withOpacity(0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.remove_circle_outline,
                    size: 15,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _SkillItemText(text: item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Splits "SkillName — explanation" into bold name + regular explanation
class _SkillItemText extends StatelessWidget {
  final String text;
  const _SkillItemText({required this.text});

  @override
  Widget build(BuildContext context) {
    final separatorIdx = text.indexOf(' — ');
    if (separatorIdx == -1) {
      return Text(text, style: const TextStyle(fontSize: 13, height: 1.4));
    }

    final skillName = text.substring(0, separatorIdx);
    final explanation = text.substring(separatorIdx + 3);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppTheme.textPrimary,
        ),
        children: [
          TextSpan(
            text: skillName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.amber,
            ),
          ),
          if (explanation.isNotEmpty)
            TextSpan(
              text: ' — $explanation',
              style: const TextStyle(
                fontWeight: FontWeight.normal,
                color: Colors.blue,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Projects Section ──────────────────────────────────────────────────────────

class _ProjectsSection extends StatelessWidget {
  final List<ProjectAnalysis> projects;
  const _ProjectsSection({required this.projects});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Project Analysis',
          icon: Icons.code_rounded,
          color: AppTheme.accent,
        ),
        const SizedBox(height: 10),
        ...projects.map((p) => _ProjectCard(project: p)),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectAnalysis project;
  const _ProjectCard({required this.project});

  Color get _complexityColor {
    switch (project.complexity) {
      case 'High':
        return AppTheme.success;
      case 'Medium':
        return AppTheme.primary;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoreCol = _scoreColor(project.score);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — name + complexity badge + score
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name.isEmpty ? 'Unnamed Project' : project.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Complexity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _complexityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  project.complexity,
                  style: TextStyle(
                    fontSize: 10,
                    color: _complexityColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Score pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreCol.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: scoreCol.withOpacity(0.3)),
                ),
                child: Text(
                  '${project.score}/100',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scoreCol,
                  ),
                ),
              ),
            ],
          ),

          // Score progress bar
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: project.score / 100,
              backgroundColor: scoreCol.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(scoreCol),
              minHeight: 4,
            ),
          ),

          // Tech stack
          if (project.techStack.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.layers_outlined,
                    size: 13,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    project.techStack,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Issues
          if (project.issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ProjectSubList(
              items: project.issues,
              icon: Icons.error_outline,
              color: AppTheme.warning,
            ),
          ],

          // Suggestions
          if (project.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ProjectSubList(
              items: project.suggestions,
              icon: Icons.lightbulb_outline,
              color: AppTheme.accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectSubList extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final Color color;
  const _ProjectSubList({
    required this.items,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Suggestions Section ───────────────────────────────────────────────────────

class _SuggestionsSection extends StatelessWidget {
  final List<String> suggestions;
  const _SuggestionsSection({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Improvement Suggestions',
          icon: Icons.lightbulb_outline,
          color: Colors.amber.shade700,
        ),
        const SizedBox(height: 10),
        ...suggestions.asMap().entries.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${e.key + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.value,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Admin Decision Card ───────────────────────────────────────────────────────

class _AdminDecisionCard extends StatelessWidget {
  final AnalysisModel analysis;
  const _AdminDecisionCard({required this.analysis});

  Color get _color {
    switch (analysis.adminDecision) {
      case 'Pass':
        return AppTheme.success;
      case 'High Potential':
        return AppTheme.primary;
      case 'Hold':
        return AppTheme.warning;
      default:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                'Recruiter Decision',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            analysis.adminDecision!,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (analysis.adminNotes != null &&
              analysis.adminNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Text(
                analysis.adminNotes!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Reusable Components ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);

  String get _label {
    switch (type) {
      case 'ats_only':
        return 'ATS Check';
      case 'custom_tech':
        return 'Custom Tech';
      default:
        return 'Job Match';
    }
  }

  Color get _color {
    switch (type) {
      case 'ats_only':
        return Colors.purple;
      case 'custom_tech':
        return AppTheme.accent;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      _label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _color,
      ),
    ),
  );
}

class _CircleScore extends StatelessWidget {
  final int score;
  final double size;
  const _CircleScore({required this.score, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5.5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Center(
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: size * 0.27,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Premium CTA at bottom of analysis ────────────────────────────────────────

class _PremiumCta extends ConsumerWidget {
  final AnalysisModel analysis;
  const _PremiumCta({required this.analysis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeAsync = ref.watch(resumeByIdProvider(analysis.resumeId));
    final resumeText = resumeAsync.whenOrNull(data: (r) => r?.extractedText) ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumHubScreen(resumeText: resumeText),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A0E1A), Color(0xFF1A1D27)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'Improve This Resume',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Premium', style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            const Text(
              'AI rewrite · JD matching · ATS boost · PDF download · Human review',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5BE3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'See All Features →',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

}
