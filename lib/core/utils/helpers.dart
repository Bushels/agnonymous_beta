import 'package:html_unescape/html_unescape.dart';
import 'package:agnonymous_beta/features/community/community_categories.dart';

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
  return iconForBoardCategory(category);
}
