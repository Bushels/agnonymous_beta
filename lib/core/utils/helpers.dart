import 'package:html_unescape/html_unescape.dart';

// --- HTML SANITIZATION ---
final _htmlUnescape = HtmlUnescape();

/// Sanitize user input to prevent XSS attacks
String sanitizeInput(String input) {
  // Remove any HTML tags
  String sanitized = input.replaceAll(RegExp(r'<[^>]*>'), '');
  // Decode HTML entities
  sanitized = _htmlUnescape.convert(sanitized);
  // Trim whitespace
  sanitized = sanitized.trim();
  return sanitized;
}

// --- UTILITY FUNCTIONS ---
String getIconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'farming': return '\u{1F69C}';
    case 'livestock': return '\u{1F404}';
    case 'ranching': return '\u{1F920}';
    case 'crops': return '\u{1F33E}';
    case 'markets': return '\u{1F4C8}';
    case 'weather': return '\u{1F326}\uFE0F';
    case 'chemicals': return '\u{1F9EA}';
    case 'equipment': return '\u{1F527}';
    case 'politics': return '\u{1F3DB}\uFE0F';
    case 'input prices': return '\u{1F4B0}';
    case 'general': return '\u{1F4DD}';
    case 'other': return '\u{1F517}';
    default: return '\u{1F4DD}';
  }
}
