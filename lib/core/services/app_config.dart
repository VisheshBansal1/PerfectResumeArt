import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class AppConfig {
  AppConfig._();

  // ── Backend ───────────────────────────────────────────────────────────────
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://resume-ai-backend-bwzx.onrender.com',
  );

  // ── Razorpay (public key — safe in binary) ────────────────────────────────
  static const razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: '',
  );

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const adminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: '',
  );
  static const adminName = String.fromEnvironment(
    'ADMIN_NAME',
    defaultValue: 'Admin',
  );

  // ── EmailJS ───────────────────────────────────────────────────────────────
  static const emailJsPublicKey = String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
    defaultValue: '',
  );
  static const emailJsServiceId = String.fromEnvironment(
    'EMAILJS_SERVICE_ID',
    defaultValue: '',
  );
  static const emailJsTemplateId = String.fromEnvironment(
    'EMAILJS_TEMPLATE_ID',
    defaultValue: '',
  );
  static const emailJsHumanReviewTemplateId = String.fromEnvironment(
    'EMAILJS_HUMAN_REVIEW_TEMPLATE_ID',
    defaultValue: '',
  );

  // ── AdMob (rewarded ads — app builds only; ignored entirely on web) ───────
  // Defaults are Google's official TEST rewarded ad unit IDs. They always
  // serve a real, functioning test ad, so the whole "watch ad to unlock"
  // flow works out of the box in debug builds without any setup.
  //
  // Before a release/production build, override both with your own AdMob
  // rewarded ad unit IDs:
  //   --dart-define=ADMOB_REWARDED_AD_UNIT_ID_ANDROID=ca-app-pub-xxx/xxx
  //   --dart-define=ADMOB_REWARDED_AD_UNIT_ID_IOS=ca-app-pub-xxx/xxx
  // ...and set your real AdMob App ID natively (this can't be done via
  // --dart-define):
  //   android/app/src/main/AndroidManifest.xml → APPLICATION_ID meta-data
  //   ios/Runner/Info.plist → GADApplicationIdentifier
  static const _admobRewardedAdUnitIdAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_AD_UNIT_ID_ANDROID',
    // Real production rewarded ad unit ID (Android), from the AdMob
    // console. Override at build time with --dart-define if you ever need
    // a different one (e.g. a staging unit) without editing this file.
    defaultValue: 'ca-app-pub-5737850023326024/9261204462',
  );
  static const _admobRewardedAdUnitIdIOS = String.fromEnvironment(
    'ADMOB_REWARDED_AD_UNIT_ID_IOS',
    // No iOS rewarded ad unit ID was provided yet, so this still falls
    // back to Google's test ID — replace with a real one via
    // --dart-define=ADMOB_REWARDED_AD_UNIT_ID_IOS=... once you create an
    // iOS rewarded ad unit in the AdMob console, or iOS builds will only
    // ever serve test ads.
    defaultValue: 'ca-app-pub-3940256099942544/1712485313', // Google test ID
  );

  /// The rewarded ad unit ID for the current platform. Only meaningful on
  /// Android/iOS — ads are never requested on web (see AdService/
  /// ad_service_web_stub.dart), so this is never read there.
  static String get admobRewardedAdUnitId {
    if (kIsWeb) return '';
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _admobRewardedAdUnitIdIOS
        : _admobRewardedAdUnitIdAndroid;
  }

  // ── Validation (call at startup to catch missing keys early) ──────────────
  static bool get isEmailConfigured =>
      emailJsPublicKey.isNotEmpty &&
      emailJsServiceId.isNotEmpty &&
      emailJsTemplateId.isNotEmpty;

  static bool get isPaymentConfigured =>
      razorpayKeyId.isNotEmpty && backendUrl.isNotEmpty;

  static void validate() {
    final missing = <String>[];
    if (backendUrl.isEmpty) missing.add('BACKEND_URL');
    if (razorpayKeyId.isEmpty) missing.add('RAZORPAY_KEY_ID');
    if (adminEmail.isEmpty) missing.add('ADMIN_EMAIL');
    if (emailJsPublicKey.isEmpty) missing.add('EMAILJS_PUBLIC_KEY');
    if (emailJsServiceId.isEmpty) missing.add('EMAILJS_SERVICE_ID');
    if (emailJsTemplateId.isEmpty) missing.add('EMAILJS_TEMPLATE_ID');

    if (missing.isNotEmpty) {
      // ignore: avoid_print
      print('[AppConfig] Missing --dart-define keys: ${missing.join(', ')}');
    }
  }
}
