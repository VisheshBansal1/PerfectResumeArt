import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/local_resume_analyzer.dart';

/// Color for a 0-100 score, shared across every local-scan widget so the
/// same number always reads the same way.
Color scanScoreColor(int score) {
  if (score >= 85) return AppTheme.success;
  if (score >= 70)
    return const Color(0xFF7CB342); // yellow-green: good, not perfect
  if (score >= 50) return AppTheme.warning;
  return AppTheme.error;
}

IconData _statusIcon(CheckStatus status) {
  switch (status) {
    case CheckStatus.pass:
      return Icons.check_circle;
    case CheckStatus.warn:
      return Icons.error_outline;
    case CheckStatus.fail:
      return Icons.cancel;
  }
}

Color _statusColor(CheckStatus status) {
  switch (status) {
    case CheckStatus.pass:
      return AppTheme.success;
    case CheckStatus.warn:
      return AppTheme.warning;
    case CheckStatus.fail:
      return AppTheme.error;
  }
}

/// A ring showing a 0-100 score with the number centered inside it.
class ScoreRing extends StatelessWidget {
  final int score;
  final double size;
  final String? caption;

  const ScoreRing({
    super.key,
    required this.score,
    this.size = 96,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final color = scanScoreColor(score);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: size * 0.09,
                    backgroundColor: color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(value * 100).round()}',
                      style: TextStyle(
                        fontSize: size * 0.30,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: TextStyle(
                        fontSize: size * 0.11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(
            caption!,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Horizontal bar for one scoring category (e.g. "Language & Impact 18/30").
class CategoryScoreBar extends StatelessWidget {
  final ScanCategoryScore category;

  const CategoryScoreBar({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final pct = category.maxScore == 0
        ? 0.0
        : category.score / category.maxScore;
    final color = scanScoreColor((pct * 100).round());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${category.score}/${category.maxScore}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct.clamp(0, 1)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the detailed findings list.
class ScanCheckTile extends StatelessWidget {
  final ResumeCheck check;

  const ScanCheckTile({super.key, required this.check});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(check.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_statusIcon(check.status), color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  check.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
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

/// The full findings list, grouped by category with a small header per group.
class ScanCheckList extends StatelessWidget {
  final List<ResumeCheck> checks;

  const ScanCheckList({super.key, required this.checks});

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<ResumeCheck>>{};
    for (final c in checks) {
      byCategory.putIfAbsent(c.category, () => []).add(c);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: byCategory.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              ...entry.value.map((c) => ScanCheckTile(check: c)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Expandable "what your ATS actually sees" raw-text preview.
class WhatAtsSeesCard extends StatefulWidget {
  final String text;
  const WhatAtsSeesCard({super.key, required this.text});

  @override
  State<WhatAtsSeesCard> createState() => _WhatAtsSeesCardState();
}

class _WhatAtsSeesCardState extends State<WhatAtsSeesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'What your ATS actually sees',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This is the raw text pulled from your file — the same thing an ATS parser reads. '
                    'If anything below looks jumbled, out of order, or missing, a real ATS will have the '
                    'same trouble with it.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.text.isEmpty
                          ? '(No text extracted yet)'
                          : widget.text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        height: 1.5,
                      ),
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

/// Small pill summarizing pass/warn/fail counts, e.g. "9 passed · 3 to fix".
class ScanTallyPill extends StatelessWidget {
  final LocalScanResult result;
  const ScanTallyPill({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, int n, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$n $label',
          style: TextStyle(
            fontSize: 11.5,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        dot(AppTheme.success, result.passCount, 'passed'),
        dot(AppTheme.warning, result.warnCount, 'to improve'),
        dot(AppTheme.error, result.failCount, 'to fix'),
      ],
    );
  }
}

/// The full, self-contained "Instant Health Scan" report: score ring,
/// category bars, tally, capped-score notice (if any), findings list, and
/// the "what ATS sees" preview. Drop this in anywhere a [LocalScanResult]
/// needs to be shown in full.
class LocalScanReport extends StatelessWidget {
  final LocalScanResult result;
  final bool showRawTextPreview;

  const LocalScanReport({
    super.key,
    required this.result,
    this.showRawTextPreview = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.purple.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ScoreRing(
                    score: result.score,
                    size: 84,
                    caption: result.scoreLabel,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Instant Health Scan',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Free, on-device pre-check — no AI call, no waiting.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ScanTallyPill(result: result),
                      ],
                    ),
                  ),
                ],
              ),
              if (result.wasCapped && result.capReason != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.priority_high,
                        color: AppTheme.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.capReason!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.error,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Score breakdown',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...result.categories.map((c) => CategoryScoreBar(category: c)),
        const SizedBox(height: 8),
        const Text(
          'Detailed findings',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ScanCheckList(checks: result.checks),
        if (showRawTextPreview) ...[
          const SizedBox(height: 4),
          WhatAtsSeesCard(text: result.rawText),
        ],
      ],
    );
  }
}
