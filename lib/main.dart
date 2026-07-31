import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/app_config.dart';
import 'core/services/referral_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
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
