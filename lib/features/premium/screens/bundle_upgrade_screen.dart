import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/payment_service.dart';
import '../../../providers/premium_providers.dart';

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
        _startBundle();
      }
    });
  }

  void _startBundle() {
    // Unlock all sub-features
    ref.read(unlockProvider.notifier).unlock('fix_resume');
    ref.read(unlockProvider.notifier).unlock('jd_optimize');
    // Start fixing immediately
    ref.read(fixResumeProvider.notifier).fix(resumeText: widget.resumeText);
  }

  Future<void> _handlePurchase() async {
    final paid = await PaywallSheet.show(
      context,
      plan: PaymentPlan.bundle,
      userEmail: widget.userEmail,
      userName: widget.userName,
    );
    if (paid && mounted) {
      await ref.read(unlockProvider.notifier).unlock('bundle');
      setState(() => _unlocked = true);
      _startBundle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Full Upgrade Bundle')),
      body: _unlocked ? _unlockedBody() : _lockedBody(),
    );
  }

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
              const Text('One-Click Full Upgrade',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Everything you need to go from rejected to selected',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              Row(children: [
                const Text('₹89', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('instead of ₹128',
                      style: TextStyle(color: Colors.white60, fontSize: 12, decoration: TextDecoration.lineThrough)),
                  Text('Save ₹39', style: TextStyle(color: Colors.yellow[300], fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // What's inside
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
                  Text(item.title,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: item.color)),
                  Text(item.desc,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              )),
              Text(item.price,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500], decoration: TextDecoration.lineThrough)),
            ]),
          )),

          const SizedBox(height: 24),

          // Social proof
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(children: [
              const Icon(Icons.people, color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Most users who buy the bundle report getting 2x more callbacks within a week',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // CTA
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
                  Text('Get Full Upgrade Bundle · ₹89',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('Save ₹39 vs buying separately',
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

  Widget _unlockedBody() {
    final state = ref.watch(fixResumeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bundle Unlocked!', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success)),
                  SizedBox(height: 2),
                  Text('All features are now active. Your resume is being processed…',
                      style: TextStyle(fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          if (state.isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Rewriting your resume…'),
              ]),
            ))
          else if (state.result != null) ...[
            const Text('Improved Resume Ready',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: SelectableText(
                state.result!.improvedText,
                style: const TextStyle(fontSize: 12, height: 1.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(fixResumeProvider.notifier).generatePdf(
                          resumeText: state.result!.improvedText,
                          name: widget.userName,
                        );
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download PDF'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _BundleItem {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final String price;
  const _BundleItem(this.icon, this.color, this.title, this.desc, this.price);
}

final _bundleItems = [
  _BundleItem(Icons.auto_fix_high, AppTheme.primary, 'Fix My Resume',
      'Bullet rewrite + summary + impact metrics', '₹39'),
  _BundleItem(Icons.manage_search, const Color(0xFF7C3AED), 'JD Optimization',
      'Keywords embedded + ATS boost', '₹49'),
  _BundleItem(Icons.picture_as_pdf, AppTheme.accent, 'PDF Download',
      'Clean ATS-friendly formatted PDF', 'Free'),
  _BundleItem(Icons.compare_arrows, AppTheme.warning, 'Before vs After View',
      'See every change clearly', 'Free'),
];
