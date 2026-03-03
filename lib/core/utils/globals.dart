import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:html_unescape/html_unescape.dart';

// Conditional imports for web-only functionality
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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

// --- HTML SANITIZATION ---
final htmlUnescape = HtmlUnescape();

/// Sanitize user input to prevent XSS attacks
String sanitizeInput(String input) {
  // Remove any HTML tags
  String sanitized = input.replaceAll(RegExp(r'<[^>]*>'), '');
  // Decode HTML entities
  sanitized = htmlUnescape.convert(sanitized);
  // Trim whitespace
  sanitized = sanitized.trim();
  return sanitized;
}

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

// --- UTILITY FUNCTIONS ---
String getIconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'farming': return '🚜';
    case 'livestock': return '🐄';
    case 'ranching': return '🤠';
    case 'crops': return '🌾';
    case 'markets': return '📈';
    case 'weather': return '🌦️';
    case 'chemicals': return '🧪';
    case 'equipment': return '🔧';
    case 'politics': return '🏛️';
    case 'input prices': return '💰';
    case 'general': return '📝';
    case 'other': return '🔗';
    default: return '📝';
  }
}
