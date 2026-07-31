// ─────────────────────────────────────────────────────────────────────────────
// lib/core/services/admin_referral_service.dart
// Phase 5 — everything gated behind the backend's requireAdmin middleware:
// campaign config, analytics, and withdrawal review. Kept separate from
// ReferralService (the regular user-facing half) since these calls are
// only ever meaningful for a role == 'admin' account.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'auth_token_helper.dart';

class CampaignConfig {
  final bool active;
  final double discountPercent;
  final double commissionPercent;
  final double minWithdrawal;
  final int holdDays;
  final double? maxCommissionPerReferral;
  final String? startDate;
  final String? endDate;

  const CampaignConfig({
    this.active = true,
    this.discountPercent = 10,
    this.commissionPercent = 20,
    this.minWithdrawal = 500,
    this.holdDays = 7,
    this.maxCommissionPerReferral,
    this.startDate,
    this.endDate,
  });

  factory CampaignConfig.fromJson(Map<String, dynamic> json) => CampaignConfig(
    active: json['active'] as bool? ?? true,
    discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 10,
    commissionPercent: (json['commissionPercent'] as num?)?.toDouble() ?? 20,
    minWithdrawal: (json['minWithdrawal'] as num?)?.toDouble() ?? 500,
    holdDays: json['holdDays'] as int? ?? 7,
    maxCommissionPerReferral: (json['maxCommissionPerReferral'] as num?)?.toDouble(),
    startDate: json['startDate'] as String?,
    endDate: json['endDate'] as String?,
  );

  CampaignConfig copyWith({
    bool? active,
    double? discountPercent,
    double? commissionPercent,
    double? minWithdrawal,
    int? holdDays,
    double? maxCommissionPerReferral,
    String? startDate,
    String? endDate,
  }) => CampaignConfig(
    active: active ?? this.active,
    discountPercent: discountPercent ?? this.discountPercent,
    commissionPercent: commissionPercent ?? this.commissionPercent,
    minWithdrawal: minWithdrawal ?? this.minWithdrawal,
    holdDays: holdDays ?? this.holdDays,
    maxCommissionPerReferral: maxCommissionPerReferral ?? this.maxCommissionPerReferral,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );
}

class TopReferrer {
  final String name;
  final int totalReferrals;
  final double lifetimeEarnings;
  const TopReferrer({required this.name, required this.totalReferrals, required this.lifetimeEarnings});

  factory TopReferrer.fromJson(Map<String, dynamic> json) => TopReferrer(
    name: json['name'] as String? ?? 'Unknown',
    totalReferrals: json['totalReferrals'] as int? ?? 0,
    lifetimeEarnings: (json['lifetimeEarnings'] as num?)?.toDouble() ?? 0,
  );
}

class WithdrawalSummary {
  final int count;
  final double total;
  const WithdrawalSummary({this.count = 0, this.total = 0});

  factory WithdrawalSummary.fromJson(Map<String, dynamic>? json) => WithdrawalSummary(
    count: json?['count'] as int? ?? 0,
    total: (json?['total'] as num?)?.toDouble() ?? 0,
  );
}

class ReferralAnalytics {
  final int totalReferralClicks;
  final int totalSignups;
  final int totalFirstPurchases;
  final double conversionRatePercent;
  final double totalCommissionsPaid;
  final double totalDiscountsGiven;
  final double referralGeneratedRevenue;
  final List<TopReferrer> topReferrers;
  final WithdrawalSummary pendingWithdrawals;
  final WithdrawalSummary approvedWithdrawals;

  const ReferralAnalytics({
    this.totalReferralClicks = 0,
    this.totalSignups = 0,
    this.totalFirstPurchases = 0,
    this.conversionRatePercent = 0,
    this.totalCommissionsPaid = 0,
    this.totalDiscountsGiven = 0,
    this.referralGeneratedRevenue = 0,
    this.topReferrers = const [],
    this.pendingWithdrawals = const WithdrawalSummary(),
    this.approvedWithdrawals = const WithdrawalSummary(),
  });

  factory ReferralAnalytics.fromJson(Map<String, dynamic> json) => ReferralAnalytics(
    totalReferralClicks: json['totalReferralClicks'] as int? ?? 0,
    totalSignups: json['totalSignups'] as int? ?? 0,
    totalFirstPurchases: json['totalFirstPurchases'] as int? ?? 0,
    conversionRatePercent: (json['conversionRatePercent'] as num?)?.toDouble() ?? 0,
    totalCommissionsPaid: (json['totalCommissionsPaid'] as num?)?.toDouble() ?? 0,
    totalDiscountsGiven: (json['totalDiscountsGiven'] as num?)?.toDouble() ?? 0,
    referralGeneratedRevenue: (json['referralGeneratedRevenue'] as num?)?.toDouble() ?? 0,
    topReferrers: ((json['topReferrers'] as List?) ?? [])
        .map((e) => TopReferrer.fromJson(e as Map<String, dynamic>))
        .toList(),
    pendingWithdrawals: WithdrawalSummary.fromJson(json['pendingWithdrawals'] as Map<String, dynamic>?),
    approvedWithdrawals: WithdrawalSummary.fromJson(json['approvedWithdrawals'] as Map<String, dynamic>?),
  );
}

class AdminWithdrawalRequest {
  final String id;
  final String userId;
  final String name;
  final String email;
  final double walletBalance;
  final double requestedAmount;
  final DateTime? requestedAt;
  final String status;

  const AdminWithdrawalRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.walletBalance,
    required this.requestedAmount,
    required this.requestedAt,
    required this.status,
  });

  factory AdminWithdrawalRequest.fromJson(Map<String, dynamic> json) => AdminWithdrawalRequest(
    id: json['id'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    name: json['name'] as String? ?? 'Unknown',
    email: json['email'] as String? ?? '',
    walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
    requestedAmount: (json['requestedAmount'] as num?)?.toDouble() ?? 0,
    requestedAt: json['requestedAt'] != null ? DateTime.tryParse(json['requestedAt'] as String) : null,
    status: json['status'] as String? ?? 'pending',
  );
}

class AdminReferralService {
  static final AdminReferralService _instance = AdminReferralService._internal();
  factory AdminReferralService() => _instance;
  AdminReferralService._internal();

  Future<Map<String, String>> _authHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await getIdTokenSafely();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<CampaignConfig?> getConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/admin/referral/config'),
        headers: await _authHeaders(),
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return CampaignConfig.fromJson(data['config'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[AdminReferral] getConfig failed: $e');
      return null;
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> updateConfig(Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.backendUrl}/api/admin/referral/config'),
        headers: await _authHeaders(),
        body: jsonEncode(updates),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) return null;
      return body['error'] as String? ?? 'Could not update campaign config.';
    } catch (e) {
      debugPrint('[AdminReferral] updateConfig failed: $e');
      return 'Could not update campaign config right now.';
    }
  }

  Future<ReferralAnalytics?> getAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/admin/referral/analytics'),
        headers: await _authHeaders(),
      );
      if (response.statusCode != 200) return null;
      return ReferralAnalytics.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[AdminReferral] getAnalytics failed: $e');
      return null;
    }
  }

  Future<List<AdminWithdrawalRequest>> listWithdrawals({String status = 'pending'}) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.backendUrl}/api/admin/referral/withdrawals?status=$status'),
        headers: await _authHeaders(),
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['withdrawals'] as List?) ?? [];
      return list.map((e) => AdminWithdrawalRequest.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[AdminReferral] listWithdrawals failed: $e');
      return [];
    }
  }

  Future<String?> approveWithdrawal(String id) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/admin/referral/withdrawals/$id/approve'),
        headers: await _authHeaders(),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) return null;
      return body['error'] as String? ?? 'Could not approve withdrawal.';
    } catch (e) {
      debugPrint('[AdminReferral] approveWithdrawal failed: $e');
      return 'Could not approve withdrawal right now.';
    }
  }

  Future<String?> rejectWithdrawal(String id, {String reason = ''}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.backendUrl}/api/admin/referral/withdrawals/$id/reject'),
        headers: await _authHeaders(),
        body: jsonEncode({'reason': reason}),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) return null;
      return body['error'] as String? ?? 'Could not reject withdrawal.';
    } catch (e) {
      debugPrint('[AdminReferral] rejectWithdrawal failed: $e');
      return 'Could not reject withdrawal right now.';
    }
  }
}
