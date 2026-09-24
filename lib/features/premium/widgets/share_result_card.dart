import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/services/referral_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Displays a tappable "Share your result" banner.
/// When tapped, shows a full-screen shareable card the user can screenshot.
///
/// Usage (add below any result screen):
///   ShareResultBanner(
///     toolName: 'Fix My Resume',
///     scoreBefore: 42,
///     scoreAfter: 78,
///     highlight: 'Bullets rewritten with impact metrics',
///   )
class ShareResultBanner extends ConsumerWidget {
  final String toolName;
  final int scoreBefore;
  final int scoreAfter;
  final String highlight;

  const ShareResultBanner({
    super.key,
    required this.toolName,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralCode = ref.watch(currentUserProvider).value?.referralCode;
    return GestureDetector(
      onTap: () => _showShareCard(context, referralCode),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D5BE3), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Show off your result!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap to create a shareable card → WhatsApp / LinkedIn',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.share, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  void _showShareCard(BuildContext context, String? referralCode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareCardSheet(
        toolName: toolName,
        scoreBefore: scoreBefore,
        scoreAfter: scoreAfter,
        highlight: highlight,
        referralCode: referralCode,
      ),
    );
  }
}

/// The bottom sheet that renders the shareable card + screenshot instructions.
class _ShareCardSheet extends StatefulWidget {
  final String toolName;
  final int scoreBefore;
  final int scoreAfter;
  final String highlight;
  final String? referralCode;

  const _ShareCardSheet({
    required this.toolName,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.highlight,
    required this.referralCode,
  });

  @override
  State<_ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<_ShareCardSheet> {
  final _cardKey = GlobalKey();
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // The shareable card (wrapped in RepaintBoundary for screenshot)
                RepaintBoundary(
                  key: _cardKey,
                  child: _ShareCard(
                    toolName: widget.toolName,
                    scoreBefore: widget.scoreBefore,
                    scoreAfter: widget.scoreAfter,
                    highlight: widget.highlight,
                  ),
                ),
                const SizedBox(height: 16),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Take a screenshot of the card above and share it on WhatsApp or LinkedIn!',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Copy text button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyShareText,
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                    label: Text(
                      _copied ? 'Copied!' : 'Copy share text for caption',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyShareText() {
    final improvement = widget.scoreAfter - widget.scoreBefore;
    final code = widget.referralCode;
    final buffer = StringBuffer(
      '🚀 Just improved my resume score from ${widget.scoreBefore}% to ${widget.scoreAfter}% '
      '(+$improvement%) using AI!\n\n'
      '✅ ${widget.highlight}\n\n'
      'Used "${widget.toolName}" on Perfect Resume Art app 🔥\n',
    );
    if (code != null && code.isNotEmpty) {
      buffer.write(
        '\nWant to try it? Use my code $code and get '
        '${AppConstants.defaultReferralDiscountPercent}% off your first premium purchase 🎉\n'
        '${ReferralService().referralLink(code)}\n',
      );
    }
    buffer.write('#Resume #JobHunt #CareerTips');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }
}

/// The actual visual card that looks good as a screenshot.
class _ShareCard extends StatelessWidget {
  final String toolName;
  final int scoreBefore;
  final int scoreAfter;
  final String highlight;

  const _ShareCard({
    required this.toolName,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final improvement = scoreAfter - scoreBefore;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0E1A), Color(0xFF1A1D35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D5BE3).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('🚀', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resume Upgraded!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      toolName,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // App brand
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D5BE3).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Perfect Resume Art',
                  style: TextStyle(
                    color: Color(0xFF2D5BE3),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Score comparison
          Row(
            children: [
              Expanded(
                child: _ScoreBox(
                  label: 'Before',
                  score: scoreBefore,
                  color: const Color(0xFFE53935),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+$improvement%',
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _ScoreBox(
                  label: 'After',
                  score: scoreAfter,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Highlight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    highlight,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
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

class _ScoreBox extends StatelessWidget {
  final String label;
  final int score;
  final Color color;

  const _ScoreBox({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$score%',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
