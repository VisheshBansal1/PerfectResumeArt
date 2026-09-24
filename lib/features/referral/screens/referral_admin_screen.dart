// ─────────────────────────────────────────────────────────────────────────────
// lib/features/referral/screens/referral_admin_screen.dart
// Phase 5 — campaign config editor, analytics rollup, and withdrawal
// approve/reject. Reachable only via Profile → "Referral Program Admin",
// itself only shown when the signed-in user has role == 'admin'.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/admin_referral_service.dart';
import '../../auth/providers/auth_provider.dart';

class ReferralAdminScreen extends ConsumerStatefulWidget {
  const ReferralAdminScreen({super.key});

  @override
  ConsumerState<ReferralAdminScreen> createState() =>
      _ReferralAdminScreenState();
}

class _ReferralAdminScreenState extends ConsumerState<ReferralAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref
        .watch(currentUserProvider)
        .maybeWhen(data: (u) => u, orElse: () => null);

    // The backend independently enforces role == 'admin' on every single
    // request this screen makes — this check is just so a non-admin who
    // navigates here directly (e.g. typing the URL) sees a clear message
    // instead of several tabs full of broken error states.
    if (user != null && user.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Referral Program Admin')),
        body: const Center(child: Text('Admin access required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Program Admin'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(text: 'Config'),
            Tab(text: 'Analytics'),
            Tab(text: 'Withdrawals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ConfigTab(), _AnalyticsTab(), _WithdrawalsTab()],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIG TAB
// ═══════════════════════════════════════════════════════════════════════════
class _ConfigTab extends StatefulWidget {
  const _ConfigTab();
  @override
  State<_ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<_ConfigTab> {
  final _service = AdminReferralService();
  bool _loading = true;
  bool _saving = false;
  CampaignConfig? _config;

  final _discountCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  final _minWithdrawalCtrl = TextEditingController();
  final _holdDaysCtrl = TextEditingController();
  final _maxCommissionCtrl = TextEditingController();
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _commissionCtrl.dispose();
    _minWithdrawalCtrl.dispose();
    _holdDaysCtrl.dispose();
    _maxCommissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final config = await _service.getConfig();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _config = config;
      if (config != null) {
        _active = config.active;
        _discountCtrl.text = config.discountPercent.toString();
        _commissionCtrl.text = config.commissionPercent.toString();
        _minWithdrawalCtrl.text = config.minWithdrawal.toString();
        _holdDaysCtrl.text = config.holdDays.toString();
        _maxCommissionCtrl.text =
            config.maxCommissionPerReferral?.toString() ?? '';
      }
    });
  }

  Future<void> _save() async {
    final updates = <String, dynamic>{
      'active': _active,
      'discountPercent': double.tryParse(_discountCtrl.text) ?? 10,
      'commissionPercent': double.tryParse(_commissionCtrl.text) ?? 20,
      'minWithdrawal': double.tryParse(_minWithdrawalCtrl.text) ?? 500,
      'holdDays': int.tryParse(_holdDaysCtrl.text) ?? 7,
      'maxCommissionPerReferral': _maxCommissionCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_maxCommissionCtrl.text),
    };

    setState(() => _saving = true);
    final error = await _service.updateConfig(updates);
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Campaign settings saved')));
    if (error == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_config == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load campaign config'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Campaign Active'),
          subtitle: const Text('Turn the whole referral program on or off'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(),
        const SizedBox(height: 8),
        _NumberField(
          label: 'Discount Percent (%)',
          controller: _discountCtrl,
          hint: 'e.g. 10',
        ),
        _NumberField(
          label: 'Commission Percent (%)',
          controller: _commissionCtrl,
          hint: 'e.g. 20',
        ),
        _NumberField(
          label: 'Minimum Withdrawal (\u20b9)',
          controller: _minWithdrawalCtrl,
          hint: 'e.g. 500',
        ),
        _NumberField(
          label: 'Commission Hold (days)',
          controller: _holdDaysCtrl,
          hint: 'e.g. 7',
        ),
        _NumberField(
          label: 'Max Commission Per Referral (\u20b9, optional)',
          controller: _maxCommissionCtrl,
          hint: 'Leave blank for unlimited',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Changes'),
          ),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  const _NumberField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ANALYTICS TAB
// ═══════════════════════════════════════════════════════════════════════════
class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();
  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  final _service = AdminReferralService();
  bool _loading = true;
  ReferralAnalytics? _analytics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final analytics = await _service.getAnalytics();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _analytics = analytics;
    });
  }

  String _money(double v) => '\u20b9${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final a = _analytics;
    if (a == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load analytics'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final stats = <(String, String, IconData, Color)>[
      (
        'Referral Clicks',
        '${a.totalReferralClicks}',
        Icons.link_rounded,
        AppTheme.primary,
      ),
      (
        'Total Signups',
        '${a.totalSignups}',
        Icons.person_add_alt_1_rounded,
        AppTheme.accent,
      ),
      (
        'First Purchases',
        '${a.totalFirstPurchases}',
        Icons.shopping_bag_rounded,
        AppTheme.success,
      ),
      (
        'Conversion Rate',
        '${a.conversionRatePercent.toStringAsFixed(1)}%',
        Icons.trending_up_rounded,
        AppTheme.warning,
      ),
      (
        'Commissions Paid',
        _money(a.totalCommissionsPaid),
        Icons.payments_rounded,
        AppTheme.primary,
      ),
      (
        'Discounts Given',
        _money(a.totalDiscountsGiven),
        Icons.local_offer_rounded,
        AppTheme.accent,
      ),
      (
        'Referral Revenue',
        _money(a.referralGeneratedRevenue),
        Icons.attach_money_rounded,
        AppTheme.success,
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: stats
                .map(
                  (s) => _AdminStatCard(
                    label: s.$1,
                    value: s.$2,
                    icon: s.$3,
                    color: s.$4,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _WithdrawalSummaryCard(
                  title: 'Pending Withdrawals',
                  summary: a.pendingWithdrawals,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WithdrawalSummaryCard(
                  title: 'Approved Withdrawals',
                  summary: a.approvedWithdrawals,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Top Referrers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (a.topReferrers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No referrers yet',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            ...a.topReferrers.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${r.totalReferrals} referrals',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(r.lifetimeEarnings),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _AdminStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.cardLight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
      ],
    ),
  );
}

class _WithdrawalSummaryCard extends StatelessWidget {
  final String title;
  final WithdrawalSummary summary;
  final Color color;
  const _WithdrawalSummaryCard({
    required this.title,
    required this.summary,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          '\u20b9${summary.total.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          '${summary.count} request${summary.count == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// WITHDRAWALS TAB
// ═══════════════════════════════════════════════════════════════════════════
class _WithdrawalsTab extends StatefulWidget {
  const _WithdrawalsTab();
  @override
  State<_WithdrawalsTab> createState() => _WithdrawalsTabState();
}

class _WithdrawalsTabState extends State<_WithdrawalsTab> {
  final _service = AdminReferralService();
  String _status = 'pending';
  bool _loading = true;
  List<AdminWithdrawalRequest> _requests = const [];
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final requests = await _service.listWithdrawals(status: _status);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _requests = requests;
    });
  }

  Future<void> _approve(AdminWithdrawalRequest r) async {
    setState(() => _processingIds.add(r.id));
    final error = await _service.approveWithdrawal(r.id);
    if (!mounted) return;
    setState(() => _processingIds.remove(r.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Approved \u20b9${r.requestedAmount.toStringAsFixed(2)} for ${r.name}',
        ),
      ),
    );
    if (error == null) _load();
  }

  Future<void> _reject(AdminWithdrawalRequest r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reject Withdrawal'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;

    setState(() => _processingIds.add(r.id));
    final error = await _service.rejectWithdrawal(r.id, reason: reason);
    if (!mounted) return;
    setState(() => _processingIds.remove(r.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Rejected withdrawal for ${r.name}')),
    );
    if (error == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'approved', label: Text('Approved')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
            ],
            selected: {_status},
            onSelectionChanged: (s) {
              setState(() => _status = s.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _requests.isEmpty
              ? Center(
                  child: Text(
                    'No $_status withdrawal requests',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _requests.length,
                    itemBuilder: (context, i) {
                      final r = _requests[i];
                      final processing = _processingIds.contains(r.id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        r.email,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\u20b9${r.requestedAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Wallet at request time: \u20b9${r.walletBalance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (_status == 'pending') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: processing
                                          ? null
                                          : () => _reject(r),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.error,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: processing
                                          ? null
                                          : () => _approve(r),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: processing
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
