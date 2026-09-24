// lib/core/services/ad_service_web_stub.dart
//
// Web stub for AdService. google_mobile_ads is a mobile-only plugin, and
// rewarded ads are an app-only feature by product decision (users on the
// website always see the purchase option only — no "watch an ad" path).
// This file exists purely so the conditional import in ad_service.dart
// resolves on web builds; every method is a safe no-op.
//
//   import 'ad_service.dart' if (dart.library.html) 'ad_service_web_stub.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static bool get isSupported => false;

  bool get isAdReady => false;

  Future<void> initialize() async {}

  void loadRewardedAd() {}

  Future<bool> showRewardedAd() async => false;

  void dispose() {}
}
