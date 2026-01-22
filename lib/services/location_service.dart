import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LocationService {
  // Private constructor
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Gets the region (province/state) based on IP address
  /// Returns null if request fails or fields are missing
  Future<String?> getRegionFromIp() async {
    try {
      // Using ip-api.com (non-commercial use is free and requires no key)
      // fields=regionName selects only the region name field
      final response = await http.get(
        Uri.parse('http://ip-api.com/json/?fields=status,regionName'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['regionName'] != null) {
          final region = data['regionName'] as String;
          debugPrint('Location detected: $region');
          return region;
        }
      }
    } catch (e) {
      debugPrint('Error getting location from IP: $e');
    }
    return null;
  }
}
