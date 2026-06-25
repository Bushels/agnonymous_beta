import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:agnonymous_beta/services/analytics_service.dart';
import 'package:agnonymous_beta/services/anonymous_id_service.dart';

import 'core/utils/globals.dart';
import 'app/theme.dart';
import 'app/navigation_shell.dart';

// --- RE-EXPORTS for backward compatibility ---
export 'core/utils/globals.dart';
export 'core/models/models.dart';
export 'app/constants.dart';
export 'features/community/providers/community_providers.dart';
export 'features/community/providers/auth_provider.dart';
export 'app/navigation_shell.dart' show MainNavigationShell, AuthWrapper;
export 'features/community/screens/community_feed_screen.dart' show HomeScreen;
export 'features/community/widgets/post_card.dart' show PostCard;

// --- MAIN APP ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
    // === STEP 1: Initialize Firebase and Anonymous Auth ===
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.i('Firebase initialized successfully');

    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
        logger.i('Signed in anonymously: ${auth.currentUser?.uid}');
      } catch (e) {
        AnonymousIdService.authInitError = e.toString();
        logger.e('Anonymous sign-in failed during main: $e');
      }
    } else {
      logger.i('Existing anonymous session found: ${auth.currentUser?.uid}');
    }
  } catch (e) {
    AnonymousIdService.authInitError = e.toString();
    logger.e('Firebase Core/Auth initialization failed: $e');
  }

  // === STEP 2: Initialize MobileAds in parallel (non-web only) ===
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
      logger.i('Mobile Ads initialized successfully');
    } catch (e) {
      logger.w('Mobile Ads initialization failed: $e');
    }
  }

  // === STEP 3: Set up Crashlytics AFTER Firebase is ready ===
  if (!kIsWeb) {
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError = (errorDetails) {
        logger.e('Flutter error: ${errorDetails.exception}',
            error: errorDetails.exception, stackTrace: errorDetails.stack);
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        logger.e('Platform error: $error', error: error, stackTrace: stack);
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      logger.i('Firebase Crashlytics initialized successfully');
    } catch (e) {
      logger.w('Firebase Crashlytics initialization failed: $e');
    }
  }

  try {
    logger.d('Initialization complete, starting app');

    // Set up custom error widget for render errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: const Color(0xFF111827),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try refreshing the page',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      details.exception.toString(),
                      style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        color: Colors.red[300],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    };

    runApp(const ProviderScope(child: AgnonymousApp()));
  } catch (e) {
    logger.e('Failed to initialize app', error: e);
    runApp(ErrorApp(message: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Error Starting App',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AgnonymousApp extends StatelessWidget {
  const AgnonymousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agnonymous',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      navigatorObservers: [
        AnalyticsService.instance.observer,
      ],
    );
  }
}
