// ─────────────────────────────────────────────────────────────────────────────
// lib/features/referral/screens/earn_refer_screen.dart
// Phase 3 — referral card, stats, wallet summary, referral history.
// Phase 4 — real withdrawal request submission (dialog + backend call) and
// unread notifications surfaced as snackbars on load, using the app's
// existing snackbar pattern rather than a new notification-center UI.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/referral_service.dart';
import '../../auth/providers/auth_provider.dart';

class EarnReferScreen extends ConsumerStatefulWidget {
  const EarnReferScreen({super.key});

  @override
  ConsumerState<EarnReferScreen> createState() => _EarnReferScreenState();
}

class _EarnReferScreenState extends ConsumerState<EarnReferScreen> {
  final _referralService = ReferralService();

  bool _loading = true;
  bool _loadFailed = false;
  bool _submittingWithdrawal = false;
  ReferralDashboardSummary? _summary;
  List<ReferralHistoryItem> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _checkNotifications();
  }

  // Runs once per screen visit (not on pull-to-refresh) — shows anything
  // that happened while the user wasn't in the app as a sequence of
  // snackbars, using the app's existing pattern rather than a new inbox UI.
  Future<void> _checkNotifications() async {
    final notifications = await _referralService.getUnreadNotifications();
    if (!mounted || notifications.isEmpty) return;

    for (final n in notifications) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n.message), duration: const Duration(seconds: 4)),
      );
      await Future.delayed(const Duration(milliseconds: 4200));
    }
    unawaited(_referralService.markAllNotificationsRead());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });

    final results = await Future.wait([
      _referralService.getDashboardSummary(),
      _referralService.getReferralHistory(),
    ]);

    if (!mounted) return;
    final summary = results[0] as ReferralDashboardSummary?;
    final history = results[1] as List<ReferralHistoryItem>;

    setState(() {
      _loading = false;
      _summary = summary;
      _history = history;
      _loadFailed = summary == null;
    });
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied'), duration: Duration(seconds: 2)),
    );
  }

  void _shareLink(String code) {
    final link = _referralService.referralLink(code);
    Share.share(
      'Get a launch discount on Perfect Resume Art — an AI resume tool that '
      'fixes, scores, and rewrites your resume in minutes. Use my link:\n$link',
    );
  }

  Future<void> _onRequestWithdrawal(ReferralDashboardSummary summary) async {
    if (summary.hasPendingWithdrawal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have a pending withdrawal request.')),
      );
      return;
    }
    if (summary.withdrawableBalance < summary.minWithdrawal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need at least \u20b9${summary.minWithdrawal.toStringAsFixed(0)} withdrawable to request a payout.',
          ),
        ),
      );
      return;
    }

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => _WithdrawalDialog(maxAmount: summary.withdrawableBalance),
    );
    if (amount == null || !mounted) return;

    setState(() => _submittingWithdrawal = true);
    final error = await _referralService.requestWithdrawal(amount);
    if (!mounted) return;
    setState(() => _submittingWithdrawal = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Withdrawal request for \u20b9${amount.toStringAsFixed(2)} submitted!'),
      ),
    );
    if (error == null) _load(); // refresh so hasPendingWithdrawal reflects the new state
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Earn & Refer')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? _LoadingSkeleton(isDark: isDark)
            : (_loadFailed)
                ? _ErrorState(isDark: isDark, onRetry: _load)
                : _buildContent(isDark, user?.referralCode ?? _summary?.referralCode),
      ),
    );
  }

  Widget _buildContent(bool isDark, String? referralCode) {
    final summary = _summary ?? const ReferralDashboardSummary();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (referralCode != null) _ReferralHeroCard(
          code: referralCode,
          link: _referralService.referralLink(referralCode),
          onCopy: () => _copyCode(referralCode),
          onShare: () => _shareLink(referralCode),
        ),
        const SizedBox(height: 20),
        _StatsGrid(stats: summary.stats),
        const SizedBox(height: 20),
        _WalletCard(
          summary: summary,
          isDark: isDark,
          submitting: _submittingWithdrawal,
          onRequestWithdrawal: () => _onRequestWithdrawal(summary),
        ),
        const SizedBox(height: 24),
        Text(
          'Referral History',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          _EmptyHistoryState(isDark: isDark, onShare: () {
            if (referralCode != null) _shareLink(referralCode);
          })
        else
          ..._history.map((item) => _HistoryTile(item: item, isDark: isDark)),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Referral Card (hero) ─────────────────────────────────────────────────────
class _ReferralHeroCard extends StatelessWidget {
  final String code;
  final String link;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _ReferralHeroCard({
    required this.code,
    required this.link,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR REFERRAL CODE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            link,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroButton(icon: Icons.copy_rounded, label: 'Copy', onTap: onCopy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroButton(icon: Icons.ios_share_rounded, label: 'Share', onTap: onShare, filled: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _HeroButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: filled ? AppTheme.primary : Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? AppTheme.primary : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final ReferralStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      (_StatCardData(Icons.link_rounded, '${stats.referralClicks}', 'Referral Clicks', AppTheme.primary)),
      (_StatCardData(Icons.person_add_alt_1_rounded, '${stats.totalSignups}', 'Signups', AppTheme.accent)),
      (_StatCardData(Icons.shopping_bag_rounded, '${stats.firstPurchases}', 'First Purchases', AppTheme.success)),
      (_StatCardData(Icons.trending_up_rounded, '${stats.conversionRatePercent.toStringAsFixed(1)}%', 'Conversion', AppTheme.warning)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.65,
      children: items.map((d) => _StatCard(data: d)).toList(),
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  _StatCardData(this.icon, this.value, this.label, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(data.icon, size: 17, color: data.color),
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          Text(
            data.label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Wallet Card ──────────────────────────────────────────────────────────────
class _WalletCard extends StatelessWidget {
  final ReferralDashboardSummary summary;
  final bool isDark;
  final bool submitting;
  final VoidCallback onRequestWithdrawal;

  const _WalletCard({
    required this.summary,
    required this.isDark,
    required this.submitting,
    required this.onRequestWithdrawal,
  });

  String _money(double v) => '\u20b9${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    final meetsMinimum = summary.withdrawableBalance >= summary.minWithdrawal;
    final eligible = meetsMinimum && !summary.hasPendingWithdrawal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Balance',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            _money(summary.walletBalance),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _WalletMiniStat(
                  label: 'Withdrawable',
                  value: _money(summary.withdrawableBalance),
                  color: AppTheme.success,
                ),
              ),
              Container(width: 1, height: 32, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              Expanded(
                child: _WalletMiniStat(
                  label: 'Pending',
                  value: _money(summary.pendingBalance),
                  color: AppTheme.warning,
                ),
              ),
              Container(width: 1, height: 32, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              Expanded(
                child: _WalletMiniStat(
                  label: 'Lifetime',
                  value: _money(summary.lifetimeEarnings),
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: submitting ? null : onRequestWithdrawal,
              style: ElevatedButton.styleFrom(
                backgroundColor: eligible ? AppTheme.primary : AppTheme.borderLight,
                foregroundColor: eligible ? Colors.white : AppTheme.textSecondary,
              ),
              child: submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(summary.hasPendingWithdrawal ? 'Withdrawal Pending Review' : 'Request Withdrawal'),
            ),
          ),
          if (!eligible && !summary.hasPendingWithdrawal) ...[
            const SizedBox(height: 8),
            Text(
              'Minimum withdrawal amount is ${_money(summary.minWithdrawal)}.',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _WalletMiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ─── Referral History ─────────────────────────────────────────────────────────
class _HistoryTile extends StatelessWidget {
  final ReferralHistoryItem item;
  final bool isDark;
  const _HistoryTile({required this.item, required this.isDark});

  Color _statusColor() {
    switch (item.status) {
      case 'completed':
        return AppTheme.success;
      case 'refunded':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  String _statusLabel() {
    switch (item.status) {
      case 'completed':
        return 'Completed';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Pending';
    }
  }

  String _dateLabel() {
    final d = item.date;
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.userName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.plan} \u00b7 \u20b9${item.purchaseAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 3),
                Text(_dateLabel(), style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+\u20b9${item.commission.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.success),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onShare;
  const _EmptyHistoryState({required this.isDark, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Icon(Icons.group_add_rounded, size: 40, color: AppTheme.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            'No referrals yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Share your link \u2014 you\u2019ll see everyone who joins and\nwhat you\u2019ve earned right here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded, size: 16),
            label: const Text('Share your link'),
          ),
        ],
      ),
    );
  }
}

// ─── Loading + Error states ───────────────────────────────────────────────────
class _LoadingSkeleton extends StatefulWidget {
  final bool isDark;
  const _LoadingSkeleton({required this.isDark});

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box({double height = 90, double? width}) {
    final base = widget.isDark ? AppTheme.cardDark : AppTheme.borderLight;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: 0.5 + (_controller.value * 0.4),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _box(height: 170),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _box(height: 90)),
            const SizedBox(width: 12),
            Expanded(child: _box(height: 90)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _box(height: 90)),
            const SizedBox(width: 12),
            Expanded(child: _box(height: 90)),
          ],
        ),
        const SizedBox(height: 20),
        _box(height: 220),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;
  const _ErrorState({required this.isDark, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: AppTheme.textSecondary.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(
              'Couldn\u2019t load your dashboard',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Check your connection and try again.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─── Withdrawal Amount Dialog ──────────────────────────────────────────────────
class _WithdrawalDialog extends StatefulWidget {
  final double maxAmount;
  const _WithdrawalDialog({required this.maxAmount});

  @override
  State<_WithdrawalDialog> createState() => _WithdrawalDialogState();
}

class _WithdrawalDialogState extends State<_WithdrawalDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.maxAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (amount > widget.maxAmount) {
      setState(() => _error = 'You can withdraw up to \u20b9${widget.maxAmount.toStringAsFixed(2)}.');
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Withdrawal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available to withdraw: \u20b9${widget.maxAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '\u20b9 ',
              labelText: 'Amount',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
