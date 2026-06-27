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

/// Generate a list of lowercase keywords of length >= 2 for search indexing
List<String> buildSearchKeywords({
  required String title,
  required String content,
  List<String?> additionalFields = const [],
}) {
  final Set<String> keywords = {};

  void addTokens(String? text) {
    if (text == null || text.trim().isEmpty) return;
    // Replace punctuation with spaces
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r"""[.,/#!$%^&*;:{}=_`~()?"'\-]"""), ' ');
    for (final token in cleaned.split(RegExp(r'\s+'))) {
      final trimmed = token.trim();
      if (trimmed.length >= 2) {
        keywords.add(trimmed);
      }
    }
  }

  addTokens(title);
  addTokens(content);
  for (final field in additionalFields) {
    if (field != null) {
      final trimmedField = field.trim().toLowerCase();
      if (trimmedField.isEmpty) continue;

      if (trimmedField.contains('@') ||
          trimmedField.contains('+') ||
          RegExp(r'\d').hasMatch(trimmedField)) {
        if (trimmedField.length >= 2) {
          keywords.add(trimmedField);
        }
      }
      addTokens(field);

      // For phone numbers specifically, extract raw digits
      if (RegExp(r'^\+?[0-9\-\s\(\)]+$').hasMatch(field)) {
        final digits = field.replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 7) {
          keywords.add(digits);
        }
      }
    }
  }

  return keywords.toList();
}
