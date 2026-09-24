import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/constants/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/app_config.dart';
import 'core/services/referral_service.dart';
import 'firebase_options.dart';

// AdMob rewarded ads — app-only feature (see ad_service_web_stub.dart, which
// makes this a harmless no-op on the web build).
import 'core/services/ad_service.dart'
    if (dart.library.html) 'core/services/ad_service_web_stub.dart';

Future<void> main() async {
  // Use path-based URLs on Flutter Web (e.g. /login) instead of the
  // default hash-based URLs (e.g. /#/login). Must be called before
  // runApp(). This is a no-op on non-web platforms, so it's safe to
  // call unconditionally here without a kIsWeb check.
  usePathUrlStrategy();

  WidgetsFlutterBinding.ensureInitialized();

  // Config values come from --dart-define at build time (no .env file needed).
  // See AppConfig for all keys and build command documentation.
  AppConfig.validate();

  // Initialize Firebase safely — wrapped so a transient init failure logs
  // instead of taking down the whole app at startup.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // On web, explicitly set auth persistence to LOCAL so the browser
    // stores the session in IndexedDB and remembers the user across page
    // reloads. Without this, Firebase web defaults to session-only persistence.
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Referral Program: grab `?ref=CODE` from the URL. Runs after Firebase
  // init so that if this ever needs auth state in the future it's there —
  // today it only touches SharedPreferences, so the ordering isn't load-
  // bearing, but there's no reason to risk it running before Firebase is ready.
  await ReferralService().captureReferralFromUrl();

  // Initialize the ad SDK and preload the first rewarded ad so it's ready
  // by the time someone hits a paywall. App-only (no-op on web) — never
  // awaited, so a slow/failed ad network never delays app startup.
  // ignore: unawaited_futures
  AdService.instance.initialize();

  runApp(const ProviderScope(child: ResumeAnalyzerApp()));
}

class ResumeAnalyzerApp extends ConsumerWidget {
  const ResumeAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Perfect Resume Art',

      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      darkTheme: AppTheme.darkTheme,

      themeMode: ThemeMode.system,

      routerConfig: router,
    );
  }
}
