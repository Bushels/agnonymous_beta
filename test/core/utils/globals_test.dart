import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/core/utils/helpers.dart';

void main() {
  group('sanitizeInput()', () {
    test('strips HTML tags', () {
      expect(sanitizeInput('<b>Bold text</b>'), 'Bold text');
      expect(sanitizeInput('<script>alert("xss")</script>'), 'alert("xss")');
      expect(sanitizeInput('<p>Paragraph</p>'), 'Paragraph');
    });

    test('strips nested HTML tags', () {
      expect(
        sanitizeInput('<div><span>Nested</span></div>'),
        'Nested',
      );
    });

    test('strips self-closing tags', () {
      expect(sanitizeInput('Line one<br/>Line two'), 'Line oneLine two');
      expect(sanitizeInput('Image: <img src="x.jpg"/>'), 'Image:');
    });

    test('handles HTML entities', () {
      expect(sanitizeInput('&amp;'), '&');
      expect(sanitizeInput('&lt;script&gt;'), '<script>');
      expect(sanitizeInput('Price &gt; \$500'), 'Price > \$500');
      expect(sanitizeInput('Farmer&#39;s Market'), "Farmer's Market");
    });

    test('trims whitespace', () {
      expect(sanitizeInput('  hello  '), 'hello');
      expect(sanitizeInput('\t\ttabbed\t\t'), 'tabbed');
      expect(sanitizeInput('\n  newlines\n  '), 'newlines');
    });

    test('handles empty string', () {
      expect(sanitizeInput(''), '');
    });

    test('handles string with only whitespace', () {
      expect(sanitizeInput('   '), '');
    });

    test('preserves normal text without HTML', () {
      const normalText = 'Canola prices are rising in Saskatchewan';
      expect(sanitizeInput(normalText), normalText);
    });

    test('handles combined HTML tags, entities, and whitespace', () {
      expect(
        sanitizeInput('  <b>Price &amp; Yield</b>  '),
        'Price & Yield',
      );
    });
  });

  group('getIconForCategory()', () {
    test('returns correct icon for farming', () {
      expect(getIconForCategory('farming'), '\u{1F69C}');
      expect(getIconForCategory('Farming'), '\u{1F69C}');
      expect(getIconForCategory('FARMING'), '\u{1F69C}');
    });

    test('returns correct icon for livestock', () {
      expect(getIconForCategory('livestock'), '\u{1F404}');
      expect(getIconForCategory('Livestock'), '\u{1F404}');
    });

    test('returns correct icon for ranching', () {
      expect(getIconForCategory('ranching'), '\u{1F920}');
    });

    test('returns correct icon for crops', () {
      expect(getIconForCategory('crops'), '\u{1F33E}');
    });

    test('returns correct icon for markets', () {
      expect(getIconForCategory('markets'), '\u{1F4C8}');
      expect(getIconForCategory('Markets'), '\u{1F4C8}');
    });

    test('returns correct icon for weather', () {
      // Weather emoji is a multi-codepoint sequence
      expect(getIconForCategory('weather'), '\u{1F326}\uFE0F');
    });

    test('returns correct icon for chemicals', () {
      expect(getIconForCategory('chemicals'), '\u{1F9EA}');
    });

    test('returns correct icon for equipment', () {
      expect(getIconForCategory('equipment'), '\u{1F527}');
    });

    test('returns correct icon for politics', () {
      expect(getIconForCategory('politics'), '\u{1F3DB}\uFE0F');
    });

    test('returns correct icon for input prices', () {
      expect(getIconForCategory('input prices'), '\u{1F4B0}');
      expect(getIconForCategory('Input Prices'), '\u{1F4B0}');
    });

    test('returns correct icon for general', () {
      expect(getIconForCategory('general'), '\u{1F4DD}');
    });

    test('returns correct icon for other', () {
      expect(getIconForCategory('other'), '\u{1F517}');
    });

    test('returns default icon for unknown category', () {
      expect(getIconForCategory('unknown_category'), '\u{1F4DD}');
      expect(getIconForCategory(''), '\u{1F4DD}');
      expect(getIconForCategory('xyz'), '\u{1F4DD}');
    });

    test('is case-insensitive', () {
      expect(getIconForCategory('CROPS'), getIconForCategory('crops'));
      expect(getIconForCategory('Markets'), getIconForCategory('markets'));
      expect(
          getIconForCategory('INPUT PRICES'), getIconForCategory('input prices'));
    });
  });
}
