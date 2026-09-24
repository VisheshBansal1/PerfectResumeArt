import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'app_config.dart';
import 'auth_token_helper.dart';

/// Result of checking whether a referral code is real.
class ReferralValidation {
  final bool valid;
  final String? referrerName;
  final String? error;

  const ReferralValidation({
    required this.valid,
    this.referrerName,
    this.error,
  });
}

/// The stats row on the Earn & Refer dashboard.
class ReferralStats {
  final int referralClicks;
  final int totalSignups;
  final int firstPurchases;
  final double conversionRatePercent;

  const ReferralStats({
    this.referralClicks = 0,
    this.totalSignups = 0,
    this.firstPurchases = 0,
    this.conversionRatePercent = 0,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) => ReferralStats(
    referralClicks: json['referralClicks'] as int? ?? 0,
    totalSignups: json['totalSignups'] as int? ?? 0,
    firstPurchases: json['firstPurchases'] as int? ?? 0,
    conversionRatePercent:
        (json['conversionRatePercent'] as num?)?.toDouble() ?? 0,
  );
}

/// Everything the Earn & Refer dashboard needs, in one call.
class ReferralDashboardSummary {
  final String? referralCode;
  final double walletBalance;
  final double pendingBalance;
  final double withdrawableBalance;
  final double lifetimeEarnings;
  final double minWithdrawal;
  final bool hasPendingWithdrawal;
  final double commissionPercent;
  final double discountPercent;
  final ReferralStats stats;

  const ReferralDashboardSummary({
    this.referralCode,
    this.walletBalance = 0,
    this.pendingBalance = 0,
    this.withdrawableBalance = 0,
    this.lifetimeEarnings = 0,
    this.minWithdrawal = 500,
    this.hasPendingWithdrawal = false,
    this.commissionPercent = 20,
    this.discountPercent = 10,
    this.stats = const ReferralStats(),
  });

  factory ReferralDashboardSummary.fromJson(
    Map<String, dynamic> json,
  ) => ReferralDashboardSummary(
    referralCode: json['referralCode'] as String?,
    walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
    pendingBalance: (json['pendingBalance'] as num?)?.toDouble() ?? 0,
    withdrawableBalance: (json['withdrawableBalance'] as num?)?.toDouble() ?? 0,
    lifetimeEarnings: (json['lifetimeEarnings'] as num?)?.toDouble() ?? 0,
    minWithdrawal: (json['minWithdrawal'] as num?)?.toDouble() ?? 500,
    hasPendingWithdrawal: json['hasPendingWithdrawal'] == true,
    commissionPercent: (json['commissionPercent'] as num?)?.toDouble() ?? 20,
    discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 10,
    stats: json['stats'] != null
        ? ReferralStats.fromJson(json['stats'] as Map<String, dynamic>)
        : const ReferralStats(),
  );
}

/// An unread notification about something that happened while the user
/// wasn't in the app (a referral signing up, a commission being credited).
class ReferralNotification {
  final String id;
  final String type;
  final String message;

  const ReferralNotification({
    required this.id,
    required this.type,
    required this.message,
  });

  factory ReferralNotification.fromJson(Map<String, dynamic> json) =>
      ReferralNotification(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

/// One row in the Referral History list.
class ReferralHistoryItem {
  final String id;
  final String userName;
  final String plan;
  final double purchaseAmount;
  final double commission;
  final DateTime? date;
  final String status; // 'pending' | 'completed' | 'refunded'

  const ReferralHistoryItem({
    required this.id,
    required this.userName,
    required this.plan,
    required this.purchaseAmount,
    required this.commission,
    required this.date,
    required this.status,
  });

  factory ReferralHistoryItem.fromJson(Map<String, dynamic> json) =>
      ReferralHistoryItem(
        id: json['id'] as String? ?? '',
        userName: json['userName'] as String? ?? 'A referred user',
        plan: json['plan'] as String? ?? '',
        purchaseAmount: (json['purchaseAmount'] as num?)?.toDouble() ?? 0,
        commission: (json['commission'] as num?)?.toDouble() ?? 0,
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String)
            : null,
        status: json['status'] as String? ?? 'pending',
      );
}

/// Handles the referral program's non-monetary mechanics: generating a
/// user's own shareable code, capturing `?ref=` from a link, and linking a
/// brand-new account to its referrer.
///
/// Anything that moves money — discounts, commissions, wallet writes — is
/// validated server-side instead (backend `/api/referral` routes, wired into
/// the payment flow in Phase 2). This service never writes a wallet balance.
class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  static const _pendingCodePrefsKey = 'pending_referral_code';
  static const _pendingCodeCapturedAtKey = 'pending_referral_code_captured_at';
  static const _pendingCodeMaxAge = Duration(days: 30);
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Step 1: capture ?ref= from the URL the moment the app loads (web) ─────
  // Call at startup and safe to call again later (e.g. on every router
  // redirect evaluation) — a no-op if there's no `ref` param in the current
  // URL, and skips re-tracking a click if this exact code is already the
  // one on file, so repeated calls within the same page load don't inflate
  // the click counter.
  Future<void> captureReferralFromUrl() async {
    if (!kIsWeb) return;
    try {
      final ref = Uri.base.queryParameters['ref'];
      if (ref == null || ref.trim().isEmpty) return;
      final code = ref.trim().toUpperCase();

      final prefs = await SharedPreferences.getInstance();
      final alreadyStored = prefs.getString(_pendingCodePrefsKey);
      if (alreadyStored == code)
        return; // same code already on file — nothing new to do

      await prefs.setString(_pendingCodePrefsKey, code);
      await prefs.setInt(
        _pendingCodeCapturedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('[Referral] Captured code from link: $code');
      unawaited(
        _trackClick(code),
      ); // fire-and-forget — never blocks app startup
    } catch (e) {
      debugPrint('[Referral] captureReferralFromUrl failed: $e');
    }
  }

  // Best-effort — feeds the "Referral Clicks" stat. Never awaited by callers
  // and never throws, since a failure here should never affect anything else.
  Future<void> _trackClick(String code) async {
    try {
      await http
          .post(
            Uri.parse('${AppConfig.backendUrl}/api/referral/track-click'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'code': code}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Referral] _trackClick failed (non-critical): $e');
    }
  }

  Future<String?> getPendingReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var code = prefs.getString(_pendingCodePrefsKey);

      // Defense in depth: if nothing was ever captured (e.g. this user's
      // first interaction was tapping "Sign in with Google" straight from
      // Login, or main()'s one-time capture missed for any reason), check
      // whether the CURRENT browser URL still shows a ?ref= param before
      // giving up. Reads Uri.base directly rather than go_router's state
      // purely as a second, independent source — cheap insurance that
      // doesn't depend on go_router's lifecycle having already run.
      if ((code == null || code.isEmpty) && kIsWeb) {
        final fresh = Uri.base.queryParameters['ref'];
        if (fresh != null && fresh.trim().isNotEmpty) {
          code = fresh.trim().toUpperCase();
          await prefs.setString(_pendingCodePrefsKey, code);
          await prefs.setInt(
            _pendingCodeCapturedAtKey,
            DateTime.now().millisecondsSinceEpoch,
          );
          debugPrint(
            '[Referral] Recovered code from live URL (fallback): $code',
          );
        }
      }

      if (code == null || code.isEmpty) return null;

      // Ignore (and clean up) a code captured too long ago — someone who
      // clicked a link a month ago and is only just now signing up
      // organically shouldn't have that old click retroactively attributed.
      final capturedAtMs = prefs.getInt(_pendingCodeCapturedAtKey);
      if (capturedAtMs != null) {
        final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(capturedAtMs),
        );
        if (age > _pendingCodeMaxAge) {
          await clearPendingReferralCode();
          return null;
        }
      }
      return code;
    } catch (e) {
      debugPrint('[Referral] getPendingReferralCode failed: $e');
      return null;
    }
  }

  Future<void> clearPendingReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingCodePrefsKey);
      await prefs.remove(_pendingCodeCapturedAtKey);
    } catch (e) {
      debugPrint('[Referral] clearPendingReferralCode failed: $e');
    }
  }

  // ── Step 2: live validation while typing (register screen) ────────────────
  // Goes through the backend (not a direct Firestore read) because this must
  // also work for a visitor who doesn't have an account yet.
  Future<ReferralValidation> validateCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return const ReferralValidation(valid: false);

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.backendUrl}/api/referral/validate-code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'code': trimmed}),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralValidation(
        valid: body['valid'] == true,
        referrerName: body['referrerName'] as String?,
        error: body['error'] as String?,
      );
    } catch (e) {
      debugPrint('[Referral] validateCode failed: $e');
      return const ReferralValidation(
        valid: false,
        error: 'Could not check that code right now.',
      );
    }
  }

  // ── Step 3: link a brand-new account to its referrer ───────────────────────
  // Call right after FirebaseAuth + the Firestore user doc are both created.
  // `explicitCode` wins if the person typed one manually; otherwise falls
  // back to whatever was captured from a link. No-op if neither exists.
  Future<bool> attachAfterSignup({
    String? explicitCode,
    String? explicitToken,
  }) async {
    final code = (explicitCode != null && explicitCode.trim().isNotEmpty)
        ? explicitCode.trim()
        : await getPendingReferralCode();

    if (code == null || code.isEmpty) return false;

    final attached = await _attachCode(code, explicitToken: explicitToken);
    if (attached) {
      // Only clear once it's actually landed — a failed attempt (auth not
      // settled yet, network hiccup) should be retryable, not lost. See
      // currentUserProvider, which retries this on every subsequent load
      // for as long as a pending code and no `referredBy` both remain.
      await clearPendingReferralCode();
    }
    return attached;
  }

  Future<bool> _attachCode(String code, {String? explicitToken}) async {
    // FIX: prefer a token the caller already has in hand — e.g. straight
    // from a just-resolved sign-in result (userCredential.user) — over
    // asking for FirebaseAuth's global current-user state. That state can
    // still lag right after a sign-in event, especially via Google's popup
    // flow, and even the polling fallback (getIdTokenSafely) is slower and
    // less certain than a token from an object we already know is valid.
    try {
      final token = explicitToken ?? await getIdTokenSafely();
      if (token == null) {
        debugPrint('[Referral] attachCode: no auth token available yet');
        return false;
      }

      final response = await http
          .post(
            Uri.parse('${AppConfig.backendUrl}/api/referral/attach'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'code': code}),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        debugPrint('[Referral] Attached code=$code');
        return true;
      }
      debugPrint('[Referral] Attach rejected: ${body['error']}');
      return false;
    } catch (e) {
      debugPrint('[Referral] attachCode failed: $e');
      return false;
    }
  }

  // ── Step 4: make sure every user has their own shareable code ─────────────
  // Just an identifier — no balances touched — so this is safe to do directly
  // against Firestore rather than round-tripping the backend. Call this
  // lazily (e.g. once the user doc loads) so it naturally covers both new
  // signups and everyone who already had an account before this shipped.
  Future<String> ensureReferralCode({
    required String uid,
    required String name,
    String? existingCode,
  }) async {
    if (existingCode != null && existingCode.isNotEmpty) return existingCode;

    for (var attempt = 0; attempt < 6; attempt++) {
      final candidate = _generateCandidateCode(name, attempt);
      final claimed = await _tryClaimCode(candidate, uid);
      if (claimed) return candidate;
    }

    // Vanishingly unlikely fallback if six attempts all collided.
    final fallback = _randomString(10);
    await _tryClaimCode(fallback, uid);
    return fallback;
  }

  Future<bool> _tryClaimCode(String code, String uid) async {
    final codeRef = _db
        .collection(AppConstants.referralCodesCollection)
        .doc(code);
    final userRef = _db.collection(AppConstants.usersCollection).doc(uid);

    try {
      return await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(codeRef);
        if (snap.exists) return false;
        tx.set(codeRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(userRef, {'referralCode': code});
        return true;
      });
    } catch (e) {
      debugPrint('[Referral] _tryClaimCode($code) failed: $e');
      return false;
    }
  }

  String _generateCandidateCode(String name, int attempt) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final base = cleaned.isNotEmpty
        ? cleaned.substring(0, min(8, cleaned.length))
        : 'USER';
    if (attempt == 0) {
      final suffix =
          100 + Random.secure().nextInt(900); // 3 digits, e.g. VISHESH123
      return '$base$suffix';
    }
    // Widen the random suffix on each retry so repeated collisions become
    // essentially impossible.
    return '$base${_randomString(3 + attempt)}';
  }

  String _randomString(int length) {
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => _codeAlphabet[rand.nextInt(_codeAlphabet.length)],
    ).join();
  }

  // ── Shareable link ──────────────────────────────────────────────────────
  // Uses the actual origin the app is running on (so this works correctly
  // in local/dev/staging builds too), falling back to the production
  // domain on mobile where there is no browser URL.
  String referralLink(String code) {
    if (kIsWeb) {
      return '${Uri.base.origin}/?ref=$code';
    }
    return 'https://perfectresumeart.in/?ref=$code';
  }

  // ── Earn & Refer dashboard data ─────────────────────────────────────────
  Future<Map<String, String>> _authHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await getIdTokenSafely();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<ReferralDashboardSummary?> getDashboardSummary() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.backendUrl}/api/referral/wallet'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint(
          '[Referral] getDashboardSummary: ${response.statusCode} ${response.body}',
        );
        return null;
      }
      return ReferralDashboardSummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[Referral] getDashboardSummary failed: $e');
      return null;
    }
  }

  Future<List<ReferralHistoryItem>> getReferralHistory() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.backendUrl}/api/referral/history'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['history'] as List?) ?? [];
      return list
          .map((e) => ReferralHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Referral] getReferralHistory failed: $e');
      return [];
    }
  }

  // ── Withdrawal requests (Phase 4) ───────────────────────────────────────
  // Returns null on success, or a user-facing error message on failure —
  // every failure reason (no pending duplicates, amount bounds, etc.) is
  // decided server-side, so whatever comes back here is safe to show as-is.
  Future<String?> requestWithdrawal(double amount) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.backendUrl}/api/referral/withdraw'),
            headers: await _authHeaders(),
            body: jsonEncode({'amount': amount}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) return null;
      return body['error'] as String? ?? 'Could not submit withdrawal request.';
    } catch (e) {
      debugPrint('[Referral] requestWithdrawal failed: $e');
      return 'Could not submit withdrawal request right now.';
    }
  }

  // ── Notifications (Phase 4) ─────────────────────────────────────────────
  // The app has no notification center — these feed the existing snackbar
  // pattern instead. Call getUnreadNotifications() when a screen the user
  // cares about (Earn & Refer) loads, show each as a SnackBar, then call
  // markAllNotificationsRead() so they aren't shown again next time.
  Future<List<ReferralNotification>> getUnreadNotifications() async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.backendUrl}/api/referral/notifications'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['notifications'] as List?) ?? [];
      return list
          .map((e) => ReferralNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Referral] getUnreadNotifications failed: $e');
      return [];
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await http
          .post(
            Uri.parse(
              '${AppConfig.backendUrl}/api/referral/notifications/mark-read',
            ),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint(
        '[Referral] markAllNotificationsRead failed (non-critical): $e',
      );
    }
  }
}

final unreadReferralNotificationsProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final notifications = await ReferralService().getUnreadNotifications();
  return notifications.length;
});
