import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../core/constants/app_theme.dart';
import '../../../core/services/interview_prep_service.dart';

// ─────────────────────────────────────────────────────────────────────────
// Shared premium UI pieces for the Job Fit + Interview Prep screen.
// Pure presentation — no provider reads, no network calls, no new business
// logic. Everything animated here uses TweenAnimationBuilder / Animated*
// widgets that manage their own controllers, so nothing needs manual
// dispose() beyond what StatefulWidgets below declare themselves.
// ─────────────────────────────────────────────────────────────────────────

// ── Entrance animation ──────────────────────────────────────────────────

/// Fades + slides its child in once, after an optional [delay]. Wrap any
/// section with this for a staggered "cards fade in" entrance.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.05),
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ── Count-up number ─────────────────────────────────────────────────────

class CountUpNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const CountUpNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

// ── Animated circular score ring (hero) ─────────────────────────────────

class AnimatedScoreRing extends StatelessWidget {
  final int score; // 0-100
  final Color color;
  final double size;
  final double strokeWidth;

  const AnimatedScoreRing({
    super.key,
    required this.score,
    required this.color,
    this.size = 120,
    this.strokeWidth = 11,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  progress: value / 100,
                  color: color,
                  strokeWidth: strokeWidth,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${value.round()}',
                    style: TextStyle(
                      fontSize: size * 0.26,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: size * 0.10,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0-1
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final track = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const start = -pi / 2;
    final sweep = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ── ATS dashboard stat card (animated number + progress bar) ───────────

class PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const PremiumStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const Spacer(),
              CountUpNumber(
                value: value,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  fontSize: 11.5,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value.clamp(0, 100)) / 100),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skill chip (matched / missing) ──────────────────────────────────────

class PremiumSkillChip extends StatelessWidget {
  final String label;
  final bool matched;
  const PremiumSkillChip({
    super.key,
    required this.label,
    required this.matched,
  });

  @override
  Widget build(BuildContext context) {
    final color = matched ? AppTheme.success : AppTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            matched
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trust indicator row ─────────────────────────────────────────────────

class TrustIndicatorRow extends StatelessWidget {
  const TrustIndicatorRow({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <IconData, String>{
      Icons.lock_outline_rounded: 'Secure Processing',
      Icons.auto_awesome_rounded: 'AI Powered',
      Icons.privacy_tip_outlined: 'Privacy Protected',
    };
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: items.entries
          .map(
            (e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(e.key, size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  e.value,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

// ── Empty state hint ────────────────────────────────────────────────────

class EmptyStateHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyStateHint({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: Colors.teal),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Multi-step "AI analyzing" loader ────────────────────────────────────

class AnalyzingStepsLoader extends StatefulWidget {
  const AnalyzingStepsLoader({super.key});

  @override
  State<AnalyzingStepsLoader> createState() => _AnalyzingStepsLoaderState();
}

class _AnalyzingStepsLoaderState extends State<AnalyzingStepsLoader> {
  static const _steps = [
    'Reading resume...',
    'Extracting skills...',
    'Matching job description...',
    'Calculating ATS score...',
    'Drafting interview questions...',
    'Preparing your report...',
  ];

  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 950), (t) {
      if (!mounted) return;
      setState(() {
        if (_current < _steps.length - 1) _current++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_steps.length, (i) {
          final done = i < _current;
          final active = i == _current;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: done
                        ? const Icon(
                            Icons.check_circle,
                            color: AppTheme.success,
                            size: 18,
                            key: ValueKey('done'),
                          )
                        : active
                        ? const Padding(
                            padding: EdgeInsets.all(2),
                            key: ValueKey('active'),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.teal,
                            ),
                          )
                        : Icon(
                            Icons.circle_outlined,
                            color: AppTheme.borderLight,
                            size: 18,
                            key: const ValueKey('pending'),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: done || active
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                  child: Text(_steps[i]),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Expandable resume-improvement card ──────────────────────────────────

class ExpandableImprovementCard extends StatefulWidget {
  final String text;
  const ExpandableImprovementCard({super.key, required this.text});

  @override
  State<ExpandableImprovementCard> createState() =>
      _ExpandableImprovementCardState();
}

class _ExpandableImprovementCardState extends State<ExpandableImprovementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tips_and_updates_outlined,
                      size: 15,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.text,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Copied — paste it into Fix My Resume to apply it',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text(
                    'Copy Suggestion',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

// ── Interview question card: badges, expandable answer, practice, copy ──

class PremiumQuestionCard extends StatefulWidget {
  final int number;
  final InterviewQA qa;
  const PremiumQuestionCard({
    super.key,
    required this.number,
    required this.qa,
  });

  @override
  State<PremiumQuestionCard> createState() => _PremiumQuestionCardState();
}

class _PremiumQuestionCardState extends State<PremiumQuestionCard> {
  bool _expanded = false;
  bool _practiceMode = false;
  final _practiceController = TextEditingController();

  @override
  void dispose() {
    _practiceController.dispose();
    super.dispose();
  }

  // Difficulty is real (AI-assigned); expected time is a standard heuristic
  // banded off it, not a per-question invented figure.
  String get _expectedTime {
    switch (widget.qa.difficulty) {
      case 'Easy':
        return '~2-3 min';
      case 'Hard':
        return '~6-8 min';
      default:
        return '~4-5 min';
    }
  }

  Color get _diffColor {
    switch (widget.qa.difficulty) {
      case 'Easy':
        return AppTheme.success;
      case 'Hard':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Q${widget.number}. ${widget.qa.question}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _miniTag(
                        widget.qa.category.label,
                        AppTheme.primary,
                        Icons.label_outline_rounded,
                      ),
                      _miniTag(
                        widget.qa.difficulty,
                        _diffColor,
                        Icons.bolt_rounded,
                      ),
                      _miniTag(
                        _expectedTime,
                        AppTheme.textSecondary,
                        Icons.timer_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 20),
                  Row(
                    children: const [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'AI Sample Answer',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.qa.answer,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _practiceMode = !_practiceMode),
                        icon: const Icon(Icons.edit_note_rounded, size: 17),
                        label: Text(
                          _practiceMode ? 'Hide Practice' : 'Practice Answer',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  'Q: ${widget.qa.question}\n\nA: ${widget.qa.answer}',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text(
                          'Copy',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    ],
                  ),
                  if (_practiceMode) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _practiceController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Type your own answer here to compare against the sample...',
                        hintStyle: const TextStyle(fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String text, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ── Premium unlock pricing card ─────────────────────────────────────────

class PremiumPricingCard extends StatelessWidget {
  final bool isUnlocking;
  final VoidCallback onUnlock;

  const PremiumPricingCard({
    super.key,
    required this.isUnlocking,
    required this.onUnlock,
  });

  static const _features = [
    'Full ATS Report',
    'Resume Improvements',
    'All 20 Interview Questions',
    'AI Sample Answers',
    'Downloadable PDF Report',
    'Future Updates Included',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -42,
            right: -14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Text(
                'MOST POPULAR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Unlock Complete AI Career Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._features.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.tealAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        f,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isUnlocking ? null : onUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: const Color(0xFF1E1B4B),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: isUnlocking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1E1B4B),
                          ),
                        )
                      : const Text(
                          'Unlock for ₹39',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'One-time payment · unlocked for this tool going forward',
                  style: TextStyle(color: Colors.white38, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
