import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Utility class for getting and processing IP addresses
class IpUtils {
  /// Cache the IP last 3 digits for the session
  static String? _cachedIpLast3;

  /// Get the last 3 digits of the user's IP address
  /// Returns format: "192" or "045" (padded with zeros)
  static Future<String> getIpLast3() async {
    // Return cached value if available
    if (_cachedIpLast3 != null) {
      return _cachedIpLast3!;
    }

    try {
      // Use ipify.org free API to get public IP
      final response = await http.get(
        Uri.parse('https://api.ipify.org?format=json'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ip = data['ip'] as String;

        // Extract last 3 digits
        final last3 = extractLast3Digits(ip);
        _cachedIpLast3 = last3;

        if (kDebugMode) {
          print('IP detected: $ip -> Last 3: $last3');
        }

        return last3;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting IP: $e');
      }
    }

    // Fallback: return 'xxx' if we can't get IP
    _cachedIpLast3 = 'xxx';
    return 'xxx';
  }

  /// Extract last 3 digits from IP address string
  /// IPv4: "192.168.1.123" -> "123"
  /// IPv6: "2001:0db8:85a3::8a2e:0370:7334" -> "334"
  static String extractLast3Digits(String ip) {
    // Handle IPv4 (e.g., "192.168.1.123" -> "123")
    if (ip.contains('.')) {
      final parts = ip.split('.');
      if (parts.length == 4) {
        final lastOctet = parts[3];
        // Pad with leading zeros (e.g., "5" -> "005")
        return lastOctet.padLeft(3, '0');
      }
    }

    // Handle IPv6 (e.g., "2001:0db8:85a3::8a2e:0370:7334" -> "334")
    if (ip.contains(':')) {
      final parts = ip.split(':');
      final lastSegment = parts.last;
      // Take last 3 characters
      if (lastSegment.length >= 3) {
        return lastSegment.substring(lastSegment.length - 3);
      }
      return lastSegment.padLeft(3, '0');
    }

    // Fallback
    return 'xxx';
  }

  /// Format IP last 3 for display
  /// Returns: "...192" or "...045"
  static String formatForDisplay(String? ipLast3) {
    if (ipLast3 == null || ipLast3.isEmpty) {
      return '...xxx';
    }
    return '...$ipLast3';
  }

  /// Clear cached IP (for testing or privacy)
  static void clearCache() {
    _cachedIpLast3 = null;
  }
}
