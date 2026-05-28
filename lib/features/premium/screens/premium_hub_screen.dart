import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../providers/premium_providers.dart';
import '../../../providers/resume_context_provider.dart';
import 'fix_resume_screen.dart';
import 'jd_optimize_screen.dart';
import 'why_rejected_screen.dart';
import 'premium_tools_screen.dart';
import 'bundle_upgrade_screen.dart';
import 'resume_generator_screen.dart';

class PremiumHubScreen extends ConsumerStatefulWidget {
  final String resumeText;

  const PremiumHubScreen({super.key, required this.resumeText});

  @override
  ConsumerState<PremiumHubScreen> createState() => _PremiumHubScreenState();
}

class _PremiumHubScreenState extends ConsumerState<PremiumHubScreen> {
  @override
  void initState() {
    super.initState();
    // Track funnel: user entered the premium hub
    AnalyticsService().premiumHubViewed();
  }

  /// Blocks navigation to any paid tool if no resume is loaded.
  /// Shows a clear "upload first" snackbar instead of silently failing.
  bool _requireResume(BuildContext context) {
    final ctx = ref.read(resumeContextProvider);
    if (ctx.hasResume) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 3),
        content: const Row(
          children: [
            Icon(Icons.upload_file, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Upload your resume first — tap the banner above',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.asData?.value;
    final unlocks = ref.watch(unlockProvider);
    final resumeCtx = ref.watch(resumeContextProvider);

    final detectedRole = resumeCtx.detectedRole.trim().isNotEmpty
        ? resumeCtx.detectedRole.trim()
        : 'Software Developer';
    // final resumeCtx = ref.watch(resumeContextProvider);

    final userEmail = user?.email ?? '';
    final userName = user?.name ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Premium Features',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header tagline
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.05),
              ),
              child: Row(
                children: [
                  const Text('🚀', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Go From Rejected to Selected',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'AI-powered tools to make your resume land more interviews',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Resume status banner ────────────────────────────────────────
            if (!resumeCtx.hasResume) ...[
              _NoResumeBanner(),
              const SizedBox(height: 16),
            ] else ...[
              _ResumeLoadedCard(detectedRole: detectedRole),
              const SizedBox(height: 16),
            ],

            // ── NEW: AI Resume Builder ───────────────────────────────────────
            _SectionLabel('🆕 New Feature'),
            const SizedBox(height: 10),
            _GeneratorCard(
              isUnlocked:
                  unlocks.contains('resume_generator') ||
                  unlocks.contains('bundle'),
              onTap: () {
                AnalyticsService().planViewed('resumeGenerator');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResumeGeneratorScreen(
                      userEmail: userEmail,
                      userName: userName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Section 1: Most Popular ──────────────────────────────────────
            _SectionLabel('🔥 Best Deal'),
            const SizedBox(height: 10),

            // Bundle card (highlighted)
            _BundleCard(
              isUnlocked: unlocks.contains('bundle'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BundleUpgradeScreen(
                    resumeText: widget.resumeText,
                    userEmail: userEmail,
                    userName: userName,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Fix Resume
            _FeatureCard(
              emoji: '🔧',
              title: 'Fix My Resume',
              subtitle:
                  'AI rewrites your bullets to sound impressive + PDF download',
              price: '₹39',
              color: AppTheme.primary,
              isUnlocked:
                  unlocks.contains('fix_resume') || unlocks.contains('bundle'),
              onTap: () {
                if (!_requireResume(context)) return;
                AnalyticsService().planViewed('fixResume');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FixResumeScreen(
                      resumeText: widget.resumeText,
                      userName: userName,
                      userEmail: userEmail,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // JD Optimize
            _FeatureCard(
              emoji: '🎯',
              title: 'Job Description Match',
              subtitle:
                  'Paste any job posting → AI fixes your resume to match it',
              price: '₹49',
              color: const Color(0xFF7C3AED),
              isUnlocked:
                  unlocks.contains('jd_optimize') || unlocks.contains('bundle'),
              onTap: () {
                if (!_requireResume(context)) return;
                AnalyticsService().planViewed('jdOptimize');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JdOptimizeScreen(
                      resumeText: widget.resumeText,
                      userName: userName,
                      userEmail: userEmail,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Section 2: Free Tools ────────────────────────────────────────
            _SectionLabel('🆓 Free Tools'),
            const SizedBox(height: 10),

            // Why rejected
            _FeatureCard(
              emoji: '📊',
              title: 'Why You Get Rejected',
              subtitle:
                  'Honest feedback — what\'s stopping your resume from working',
              price: 'FREE',
              color: AppTheme.error,
              isUnlocked: true,
              isFree: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      WhyRejectedScreen(resumeText: widget.resumeText),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Project improver
            _FeatureCard(
              emoji: '🧠',
              title: 'Make Projects Sound Better',
              subtitle:
                  '"Built an app" → "Launched app with 5,000 users" (AI magic)',
              price: 'FREE',
              color: AppTheme.accent,
              isUnlocked: true,
              isFree: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProjectImproverScreen(),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Selection booster
            _FeatureCard(
              emoji: '📈',
              title: 'What to Add to Get Shortlisted',
              subtitle: 'AI tells you exactly what\'s missing from your resume',
              price: 'FREE',
              color: AppTheme.warning,
              isUnlocked: true,
              isFree: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SelectionBoosterScreen(resumeText: widget.resumeText),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Section 3: Expert ────────────────────────────────────────────
            _SectionLabel('👤 Expert Help'),
            const SizedBox(height: 10),

            _FeatureCard(
              emoji: '👨‍💻',
              title: 'Real Human Checks Your Resume',
              subtitle:
                  'An expert personally rewrites your resume — delivered in 24 hrs',
              price: '₹129',
              color: Colors.grey[800]!,
              isUnlocked:
                  unlocks.contains('human_review') ||
                  unlocks.contains('bundle'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HumanReviewScreen(
                    userEmail: userEmail,
                    userName: userName,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      letterSpacing: 0.5,
    ),
  );
}

// ── Helper: pick and replace resume (used by both banner and loaded card) ─────
Future<void> _pickAndReplaceResume(BuildContext context, WidgetRef ref) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Reading your resume...'),
            ],
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }

    final ocr = OcrService();
    final result2 = await ocr.extractTextFromBytes(
      bytes: Uint8List.fromList(file.bytes!),
      extension: 'pdf',
    );

    if (result2.text.trim().length > 80) {
      await ref
          .read(resumeContextProvider.notifier)
          .setResumeWithPdf(
            result2.text,
            source: 'upload',
            pdfBytes: Uint8List.fromList(file.bytes!),
            originalFileName: file.name,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Resume updated! All tools are ready.'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read PDF. Try a text-based PDF file.'),
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

// ── Resume loaded card (shown when resume is in context) ──────────────────────
class _ResumeLoadedCard extends ConsumerWidget {
  final String detectedRole;
  const _ResumeLoadedCard({required this.detectedRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = detectedRole.isNotEmpty ? detectedRole : 'Software Developer';
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.success.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.success.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Top row — status
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppTheme.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resume Uploaded ✅',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Detected role: $role',
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: AppTheme.success.withOpacity(0.2)),

          // Action row: Change + Remove
          Row(
            children: [
              // Change resume
              Expanded(
                child: InkWell(
                  onTap: () => _pickAndReplaceResume(context, ref),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.upload_file_rounded,
                          size: 15,
                          color: AppTheme.success.withOpacity(0.85),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Change Resume',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Vertical divider
              Container(
                width: 1,
                height: 38,
                color: AppTheme.success.withOpacity(0.2),
              ),

              // Remove resume — clears context
              Expanded(
                child: InkWell(
                  onTap: () => _confirmRemove(context, ref),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 15,
                          color: AppTheme.error.withOpacity(0.75),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Remove Resume',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.error.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Confirm before removing so user doesn't accidentally clear their resume
  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Resume?'),
        content: const Text(
          'This will clear your uploaded resume from all tools. '
          'You can re-upload anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(resumeContextProvider.notifier).clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Resume removed'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text('Remove', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _NoResumeBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _pickAndUploadResume(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.upload_file,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload Your Resume to Begin',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap here to upload PDF — used by all tools automatically',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadResume(BuildContext context, WidgetRef ref) async {
    await _pickAndReplaceResume(context, ref);
  }

  Future<String> _extractPdfText(List<int> bytes) async {
    try {
      final ocr = OcrService();
      final result = await ocr.extractTextFromBytes(
        bytes: Uint8List.fromList(bytes),
        extension: 'pdf',
      );
      return result.text;
    } catch (_) {
      return '';
    }
  }
}

class _GeneratorCard extends StatelessWidget {
  final bool isUnlocked;
  final VoidCallback onTap;
  const _GeneratorCard({required this.isUnlocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF2D5BE3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'AI Resume Builder',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      _NewBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Don't have a resume? AI builds one from scratch",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        '₹49',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Resume + PDF + LinkedIn summary',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUnlocked ? Icons.check : Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.25),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'NEW',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _BundleCard extends StatelessWidget {
  final bool isUnlocked;
  final VoidCallback onTap;
  const _BundleCard({required this.isUnlocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFE53935)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Full Bundle — Use Everything Free',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(width: 8),
                      _BestValueBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pay once → All 5 tools unlocked forever (AI Builder + Fix + JD Match + Expert Review + PDF)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        '₹79',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹266 if bought separately',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUnlocked ? Icons.check : Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestValueBadge extends StatelessWidget {
  const _BestValueBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.25),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'SAVE ₹187',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String price;
  final Color color;
  final bool isUnlocked;
  final bool isFree;
  final VoidCallback onTap;
  final Color? priceColor;

  const _FeatureCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.color,
    required this.isUnlocked,
    required this.onTap,
    this.isFree = false,
    this.priceColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnlocked && !isFree
                ? AppTheme.success.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isFree)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FREE',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else if (isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '✓ UNLOCKED',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  Text(
                    price,
                    style: TextStyle(
                      color: priceColor ?? Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, color: Colors.white30, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
