import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:agnonymous_beta/services/anonymous_id_service.dart';
import 'package:agnonymous_beta/services/analytics_service.dart';

import 'core/utils/globals.dart';
import 'app/theme.dart';
import 'app/navigation_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';

// --- RE-EXPORTS for backward compatibility ---
export 'core/utils/globals.dart';
export 'core/models/models.dart';
export 'app/constants.dart';
export 'features/community/providers/community_providers.dart';
export 'app/navigation_shell.dart' show MainNavigationShell, AuthWrapper;
export 'features/community/screens/community_feed_screen.dart' show HomeScreen;
export 'features/community/widgets/post_card.dart' show PostCard;

// --- MAIN APP ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AnonymousIdService.getAnonymousId();

  // === STEP 1: Resolve Supabase credentials synchronously (no network calls) ===
  String? supabaseUrl;
  String? supabaseAnonKey;

  // Try JavaScript window.ENV first (Firebase hosting)
  if (kIsWeb) {
    supabaseUrl = getWebEnvironmentVariable('SUPABASE_URL');
    supabaseAnonKey = getWebEnvironmentVariable('SUPABASE_ANON_KEY');
  }

  // Try dart-define (production)
  if (supabaseUrl?.isEmpty != false || supabaseAnonKey?.isEmpty != false) {
    supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
    supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  }

  // Try .env file only if still missing (development only, adds latency)
  if (supabaseUrl?.isEmpty != false || supabaseAnonKey?.isEmpty != false) {
    try {
      await dotenv.load(fileName: ".env");
      supabaseUrl = dotenv.env['SUPABASE_URL'];
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    } catch (e) {
      // .env file not found, which is okay for production builds
    }
  }

  if (supabaseUrl == null || supabaseUrl.isEmpty ||
      supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('Supabase credentials not found. Please check environment variables or .env file.');
  }

  // === STEP 2: Initialize Firebase, Supabase, and MobileAds in PARALLEL ===
  try {
    final futures = <Future<void>>[];

    // Firebase initialization
    futures.add(Firebase.initializeApp().then((_) {
      logger.i('Firebase initialized successfully');
    }).catchError((e) {
      logger.w('Firebase initialization failed (may already be initialized in web): $e');
    }));

    // Supabase initialization
    futures.add(Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).then((_) {
      logger.i('Supabase initialized successfully');
    }));

    // MobileAds initialization (non-web only)
    if (!kIsWeb) {
      futures.add(MobileAds.instance.initialize().then((_) {
        logger.i('Mobile Ads initialized successfully');
      }).catchError((e) {
        logger.w('Mobile Ads initialization failed: $e');
      }));
    }

    // Wait for all to complete in parallel
    await Future.wait(futures);
  } catch (e) {
    logger.e('Initialization error: $e');
    rethrow;
  }

  // === STEP 3: Set up Crashlytics AFTER Firebase is ready ===
  if (!kIsWeb) {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError = (errorDetails) {
        logger.e('Flutter error: ${errorDetails.exception}', error: errorDetails.exception, stackTrace: errorDetails.stack);
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

    // Check for existing session (don't auto-sign in - let AuthWrapper handle login flow)
    final session = supabase.auth.currentSession;
    if (session != null) {
      logger.d('Found existing session for user: ${session.user.id}');
    } else {
      logger.d('No existing session - user will be directed to login screen');
    }

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
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/verify-email': (context) => const VerifyEmailScreen(),
      },
      navigatorObservers: [
        AnalyticsService.instance.observer,
      ],
    );
  }
}
