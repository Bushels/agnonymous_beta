import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

// Conditional imports for web-only functionality
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// Re-export pure utility functions from helpers.dart
export 'package:agnonymous_beta/core/utils/helpers.dart';

// --- SUPABASE CLIENT ---
final supabase = Supabase.instance.client;

// --- LOGGER ---
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    printTime: false,
  ),
  level: kReleaseMode ? Level.warning : Level.debug,
);

String? getWebEnvironmentVariable(String key) {
  if (kIsWeb) {
    try {
      // Access window.ENV from JavaScript using dart:js_interop
      final global = web.window as JSObject;
      if (global.has('ENV')) {
        final env = global.getProperty('ENV'.toJS) as JSObject?;
        if (env != null && env.has(key)) {
          final val = env.getProperty(key.toJS) as JSString?;
          return val?.toDart;
        }
      }
    } catch (e) {
      logger.w('Failed to read web environment variable $key: $e');
    }
  }
  return null;
}
