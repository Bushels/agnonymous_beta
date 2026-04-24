import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/main.dart' show sanitizeInput;

void main() {
  group('sanitizeInput', () {
    group('HTML tag removal', () {
      test('removes simple HTML tags', () {
        expect(sanitizeInput('<b>bold</b>'), 'bold');
        expect(sanitizeInput('<i>italic</i>'), 'italic');
        expect(sanitizeInput('<u>underline</u>'), 'underline');
      });

      test('removes script tags', () {
        expect(sanitizeInput('<script>alert("xss")</script>'), 'alert("xss")');
        expect(sanitizeInput('<SCRIPT>malicious()</SCRIPT>'), 'malicious()');
      });

      test('removes nested tags', () {
        expect(sanitizeInput('<div><p><span>text</span></p></div>'), 'text');
      });

      test('removes self-closing tags', () {
        expect(sanitizeInput('<br/>'), '');
        expect(sanitizeInput('<img src="x"/>'), '');
        expect(sanitizeInput('Hello<br/>World'), 'HelloWorld');
      });

      test('removes tags with attributes', () {
        expect(sanitizeInput('<a href="http://evil.com">link</a>'), 'link');
        expect(sanitizeInput('<img src="x" onerror="alert(1)">'), '');
        expect(sanitizeInput('<div class="danger" onclick="hack()">content</div>'), 'content');
      });

      test('removes style tags', () {
        expect(sanitizeInput('<style>body{display:none}</style>'), 'body{display:none}');
      });

      test('handles malformed tags', () {
        expect(sanitizeInput('<div>text'), 'text');
        expect(sanitizeInput('text</div>'), 'text');
        expect(sanitizeInput('<>empty<>'), 'empty');
      });
    });

    group('HTML entity decoding', () {
      test('decodes common entities', () {
        expect(sanitizeInput('&amp;'), '&');
        expect(sanitizeInput('&lt;'), '<');
        expect(sanitizeInput('&gt;'), '>');
        expect(sanitizeInput('&quot;'), '"');
        expect(sanitizeInput('&#39;'), "'");
      });

      test('decodes multiple entities', () {
        expect(sanitizeInput('&lt;script&gt;'), '<script>');
        expect(sanitizeInput('Tom &amp; Jerry'), 'Tom & Jerry');
      });

      test('decodes numeric entities', () {
        expect(sanitizeInput('&#60;'), '<');
        expect(sanitizeInput('&#62;'), '>');
      });

      test('decodes special characters', () {
        // Note: &nbsp; alone gets decoded then trimmed to empty
        expect(sanitizeInput('Hello&nbsp;World'), contains('\u00A0')); // non-breaking space preserved in middle
        expect(sanitizeInput('&copy;'), '\u00A9'); // copyright
      });
    });

    group('whitespace handling', () {
      test('trims leading whitespace', () {
        expect(sanitizeInput('   hello'), 'hello');
        expect(sanitizeInput('\t\ttext'), 'text');
        expect(sanitizeInput('\n\nstart'), 'start');
      });

      test('trims trailing whitespace', () {
        expect(sanitizeInput('hello   '), 'hello');
        expect(sanitizeInput('text\t\t'), 'text');
        expect(sanitizeInput('end\n\n'), 'end');
      });

      test('trims both ends', () {
        expect(sanitizeInput('   middle   '), 'middle');
        expect(sanitizeInput('\t\ntext\n\t'), 'text');
      });

      test('preserves internal whitespace', () {
        expect(sanitizeInput('hello world'), 'hello world');
        expect(sanitizeInput('line1\nline2'), 'line1\nline2');
        expect(sanitizeInput('tab\tseparated'), 'tab\tseparated');
      });
    });

    group('XSS prevention', () {
      test('handles javascript: URLs', () {
        expect(sanitizeInput('<a href="javascript:alert(1)">click</a>'), 'click');
      });

      test('handles event handlers', () {
        expect(sanitizeInput('<div onmouseover="evil()">hover</div>'), 'hover');
        expect(sanitizeInput('<input onfocus="steal()">'), '');
      });

      test('handles data URLs', () {
        expect(sanitizeInput('<img src="data:image/png;base64,evil">'), '');
      });

      test('handles encoded XSS attempts', () {
        // Double encoded
        expect(sanitizeInput('&lt;script&gt;alert(1)&lt;/script&gt;'), '<script>alert(1)</script>');
      });
    });

    group('edge cases', () {
      test('handles empty string', () {
        expect(sanitizeInput(''), '');
      });

      test('handles only whitespace', () {
        expect(sanitizeInput('   '), '');
        expect(sanitizeInput('\t\n\r'), '');
      });

      test('handles only tags', () {
        expect(sanitizeInput('<br/><hr/>'), '');
        expect(sanitizeInput('<div></div>'), '');
      });

      test('preserves plain text', () {
        expect(sanitizeInput('Hello, World!'), 'Hello, World!');
        expect(sanitizeInput('Regular text with numbers 123'), 'Regular text with numbers 123');
      });

      test('preserves special characters that are not HTML', () {
        expect(sanitizeInput('Price: \$100'), 'Price: \$100');
        expect(sanitizeInput('Email: test@example.com'), 'Email: test@example.com');
        expect(sanitizeInput('Math: 5 > 3 & 2 < 4'), 'Math: 5 > 3 & 2 < 4');
      });

      test('handles unicode text', () {
        expect(sanitizeInput('Hello 世界'), 'Hello 世界');
        expect(sanitizeInput('Emoji 🌾🚜'), 'Emoji 🌾🚜');
      });

      test('handles very long input', () {
        final longText = 'a' * 10000;
        expect(sanitizeInput(longText), longText);
      });
    });

    group('real-world agricultural content', () {
      test('sanitizes post content with HTML', () {
        final input = '<p>Seen Roundup at <b>\$12.50/L</b> at Nutrien</p>';
        expect(sanitizeInput(input), 'Seen Roundup at \$12.50/L at Nutrien');
      });

      test('preserves fertilizer analysis', () {
        expect(sanitizeInput('MAP 11-52-0'), 'MAP 11-52-0');
        expect(sanitizeInput('DAP 18-46-0'), 'DAP 18-46-0');
        expect(sanitizeInput('Urea 46-0-0'), 'Urea 46-0-0');
      });

      test('preserves price formatting', () {
        expect(sanitizeInput('\$850.00/tonne'), '\$850.00/tonne');
        expect(sanitizeInput('C\$925.50/mt'), 'C\$925.50/mt');
      });

      test('preserves location names', () {
        expect(sanitizeInput('Regina, Saskatchewan'), 'Regina, Saskatchewan');
        expect(sanitizeInput("St. John's, Newfoundland"), "St. John's, Newfoundland");
      });
    });
  });
}
