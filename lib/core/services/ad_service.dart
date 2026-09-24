// lib/core/services/ad_service.dart
//
// AdMob rewarded-ad service — MOBILE (Android/iOS) implementation.
//
// This is an app-only feature: it is never shown on the Flutter Web build.
// Every call site imports this file with a conditional swap so that on web
// the harmless no-op in ad_service_web_stub.dart is used instead:
//
//   import 'ad_service.dart' if (dart.library.html) 'ad_service_web_stub.dart';
//
// Both files expose the exact same `AdService` API, so calling code never
// needs to branch on platform itself — just check `AdService.isSupported`
// before showing any "watch an ad" UI.
//
// SETUP REQUIRED before shipping a release build:
//   1. Add the google_mobile_ads package to pubspec.yaml.
//   2. Add your real AdMob App ID to:
//        android/app/src/main/AndroidManifest.xml
//          <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
//                     android:value="ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx"/>
//        ios/Runner/Info.plist
//          <key>GADApplicationIdentifier</key>
//          <string>ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx</string>
//   3. Replace the default (Google TEST) ad unit IDs in app_config.dart with
//      your real rewarded ad unit IDs via --dart-define at build time.
//   Until step 2/3 are done with real IDs, this only ever serves Google's
//   test ads — safe for development, but must be swapped before release.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_config.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  /// Always true here (this is the mobile implementation). The web stub
  /// overrides this to false.
  static bool get isSupported => !kIsWeb;

  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  int _loadAttempts = 0;
  static const _maxLoadAttempts = 3;

  /// Whether a rewarded ad is preloaded and ready to show instantly.
  bool get isAdReady => _rewardedAd != null;

  /// Call once at app startup. Initializes the Google Mobile Ads SDK and
  /// kicks off the first preload so an ad is ready by the time the user
  /// hits a paywall. Never throws — ad failures must never affect the rest
  /// of the app (the purchase path always keeps working regardless).
  Future<void> initialize() async {
    if (!isSupported) return;
    try {
      await MobileAds.instance.initialize();
      loadRewardedAd();
    } catch (e) {
      debugPrint('[AdService] initialize failed: $e');
    }
  }

  /// Preloads a rewarded ad in the background. Safe to call repeatedly —
  /// it's a no-op while a load is already in flight or one is already
  /// sitting ready. Call this again after every shown/dismissed/failed ad
  /// so there's always a fresh one queued up for next time.
  void loadRewardedAd() {
    if (!isSupported || _isLoading || _rewardedAd != null) return;
    _isLoading = true;
    RewardedAd.load(
      adUnitId: AppConfig.admobRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _loadAttempts = 0;
          _rewardedAd = ad;
          debugPrint('[AdService] Rewarded ad loaded and ready');
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _rewardedAd = null;
          _loadAttempts++;
          debugPrint('[AdService] Rewarded ad failed to load: $error');
          // Transient network/no-fill errors shouldn't permanently strand
          // the free path — retry a few times with backoff. The paywall's
          // purchase button is unaffected either way.
          if (_loadAttempts < _maxLoadAttempts) {
            Future.delayed(
              Duration(seconds: 5 * _loadAttempts),
              loadRewardedAd,
            );
          }
        },
      ),
    );
  }

  /// Shows the preloaded rewarded ad and waits for it to finish.
  /// Returns true ONLY if the user watched it through to completion and
  /// AdMob actually granted the reward callback — closing early, an ad
  /// that fails to display, or no ad being ready all return false. Callers
  /// should treat false as "fall back to the purchase option", never as
  /// "grant access anyway".
  Future<bool> showRewardedAd() async {
    if (!isSupported) return false;
    final ad = _rewardedAd;
    if (ad == null) {
      // Nothing ready — queue one up for next time and let the caller
      // fall back to the paid option now rather than blocking on a load.
      loadRewardedAd();
      return false;
    }

    _rewardedAd = null; // consumed — a shown ad instance can't be reused
    var earnedReward = false;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] Rewarded ad failed to show: $error');
        ad.dispose();
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earnedReward = true;
        },
      );
    } catch (e) {
      debugPrint('[AdService] show() threw: $e');
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
