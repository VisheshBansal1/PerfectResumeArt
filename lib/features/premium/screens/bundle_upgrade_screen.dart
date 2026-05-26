import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/payment_service.dart';
import '../../../providers/premium_providers.dart';
import '../../../providers/resume_context_provider.dart';
import 'fix_resume_screen.dart';
import 'jd_optimize_screen.dart';
import 'resume_generator_screen.dart';
import 'premium_tools_screen.dart';

class BundleUpgradeScreen extends ConsumerStatefulWidget {
  final String resumeText;
  final String userEmail;
  final String userName;

  const BundleUpgradeScreen({
    super.key,
    required this.resumeText,
    required this.userEmail,
    required this.userName,
  });

  @override
  ConsumerState<BundleUpgradeScreen> createState() => _BundleUpgradeScreenState();
}

class _BundleUpgradeScreenState extends ConsumerState<BundleUpgradeScreen> {
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final unlocks = ref.read(unlockProvider);
      if (unlocks.contains('bundle')) {
        setState(() => _unlocked = true);
        // Do NOT auto-start fix here — let user choose which tool to open
      }
    });
  }

  void _unlockAllFeatures() {
    ref.read(unlockProvider.notifier).unlock('fix_resume');
    ref.read(unlockProvider.notifier).unlock('jd_optimize');
    ref.read(unlockProvider.notifier).unlock('resume_generator');
    ref.read(unlockProvider.notifier).unlock('human_review');
    ref.read(unlockProvider.notifier).unlock('bundle');
  }

  Future<void> _handlePurchase() async {
    final paid = await PaywallSheet.show(
      context,
      plan: PaymentPlan.bundle,
      userEmail: widget.userEmail,
      userName: widget.userName,
    );
    if (paid && mounted) {
      _unlockAllFeatures();
      setState(() => _unlocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Full Upgrade Bundle')),
      body: _unlocked ? _unlockedBody() : _lockedBody(),
    );
  }

  // ── LOCKED: Sales page ─────────────────────────────────────────────────────
  Widget _lockedBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Value hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFE53935)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('BEST VALUE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              const Text('One Payment -> Everything Unlocked',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('All 5 premium tools - use them as many times as you want. No extra charges.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              Row(children: [
                const Text('₹79', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('₹266 if bought separately',
                      style: TextStyle(color: Colors.white60, fontSize: 12, decoration: TextDecoration.lineThrough)),
                  Text('You save ₹187 (70% off)', style: TextStyle(color: Colors.yellow[300], fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          const Text("What's inside:", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 14),
          ..._bundleItems.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: item.color.withOpacity(0.2)),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: item.color)),
                  Text(item.desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              )),
              Text(item.price,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500], decoration: TextDecoration.lineThrough)),
            ]),
          )),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.people, color: AppTheme.primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Most users who buy the bundle get 2x more interview callbacks within a week',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _handlePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Get All 5 Tools — ₹79',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('Save ₹187 vs buying separately',
                      style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── UNLOCKED: Tool launcher (no auto-API call) ─────────────────────────────
  Widget _unlockedBody() {
    final ctx = ref.watch(resumeContextProvider);
    final resumeText = ctx.hasResume ? ctx.text : widget.resumeText;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 28),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bundle Unlocked!',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.success)),
                SizedBox(height: 3),
                Text('All 5 tools are free for you. Tap any tool below to use it.',
                    style: TextStyle(fontSize: 12, height: 1.4)),
              ])),
            ]),
          ),
          const SizedBox(height: 24),

          const Text('Choose a tool:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 14),

          // Tool 1: AI Resume Builder
          _ToolTile(
            icon: Icons.auto_awesome,
            color: AppTheme.primary,
            title: 'AI Resume Builder',
            subtitle: 'Build a brand-new, top-tier resume from scratch',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ResumeGeneratorScreen(
                userEmail: widget.userEmail,
                userName: widget.userName,
              ),
            )),
          ),
          const SizedBox(height: 10),

          // Tool 2: Fix My Resume
          _ToolTile(
            icon: Icons.auto_fix_high,
            color: const Color(0xFF2D5BE3),
            title: 'Fix My Resume',
            subtitle: 'AI rewrites bullets to sound impressive + PDF download',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FixResumeScreen(
                resumeText: resumeText,
                userName: widget.userName,
                userEmail: widget.userEmail,
              ),
            )),
          ),
          const SizedBox(height: 10),

          // Tool 3: JD Match
          _ToolTile(
            icon: Icons.manage_search,
            color: const Color(0xFF7C3AED),
            title: 'Job Description Match',
            subtitle: 'Paste any job posting - AI tailors your resume to match it',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => JdOptimizeScreen(
                resumeText: resumeText,
                userName: widget.userName,
                userEmail: widget.userEmail,
              ),
            )),
          ),
          const SizedBox(height: 10),

          // Tool 4: Human Review
          _ToolTile(
            icon: Icons.person_search,
            color: Colors.grey.shade700,
            title: 'Real Human Expert Review',
            subtitle: 'A person personally rewrites your resume - delivered in 24 hrs',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => HumanReviewScreen(
                userEmail: widget.userEmail,
                userName: widget.userName,
              ),
            )),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Tool tile widget ──────────────────────────────────────────────────────────
class _ToolTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: color)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.4)),
            ],
          )),
          Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

// ── Bundle items list ────────────────────────────────────────────────────────
class _BundleItem {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final String price;
  const _BundleItem(this.icon, this.color, this.title, this.desc, this.price);
}

final _bundleItems = [
  _BundleItem(Icons.auto_awesome, AppTheme.primary, 'AI Resume Builder',
      'AI creates a brand new resume from your uploaded PDF', 'Rs.49'),
  _BundleItem(Icons.auto_fix_high, const Color(0xFF2D5BE3), 'Fix My Resume',
      'AI rewrites your bullets to sound impressive + impact numbers', 'Rs.39'),
  _BundleItem(Icons.manage_search, const Color(0xFF7C3AED), 'Job Description Match',
      'Paste any job posting - AI fixes your resume to match it exactly', 'Rs.49'),
  _BundleItem(Icons.person_search, Colors.grey.shade700, 'Real Human Expert Review',
      'A person manually rewrites your resume and sends it in 24 hrs', 'Rs.129'),
  _BundleItem(Icons.picture_as_pdf, AppTheme.accent, 'PDF Download (All Tools)',
      'Download any improved resume as a clean, ATS-friendly PDF', 'Free'),
];