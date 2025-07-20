import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Only import dart:html when running on web
import 'dart:html' if (dart.library.io) 'dart:io' as html;

class EnvConfig {
  static String? get supabaseUrl {
    if (kIsWeb) {
      try {
        // Try to get from window.ENV first (production)
        final window = html.window;
        final windowEnv = window as dynamic;
        final env = windowEnv.ENV;
        if (env != null && env['SUPABASE_URL'] != null) {
          return env['SUPABASE_URL'];
        }
      } catch (e) {
        // If window.ENV doesn't exist, fall through to dotenv
      }
    }
    // Fall back to .env file (development)
    return dotenv.env['SUPABASE_URL'];
  }

  static String? get supabaseAnonKey {
    if (kIsWeb) {
      try {
        // Try to get from window.ENV first (production)
        final window = html.window;
        final windowEnv = window as dynamic;
        final env = windowEnv.ENV;
        if (env != null && env['SUPABASE_ANON_KEY'] != null) {
          return env['SUPABASE_ANON_KEY'];
        }
      } catch (e) {
        // If window.ENV doesn't exist, fall through to dotenv
      }
    }
    // Fall back to .env file (development)
    return dotenv.env['SUPABASE_ANON_KEY'];
  }
}