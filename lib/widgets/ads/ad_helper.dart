import 'dart:io';
import 'package:flutter/foundation.dart';

class AdHelper {
  // Test App ID for Android
  static String get androidAppId => 'ca-app-pub-3940256099942544~3347511713';
  // Test App ID for iOS
  static String get iosAppId => 'ca-app-pub-3940256099942544~1458002511';

  static String get bannerAdUnitId {
    if (kIsWeb) {
      // For Web, we don't use AdMob Unit IDs in the same way, 
      // but we might return a slot ID for AdSense if needed.
      return 'YOUR_ADSENSE_SLOT_ID'; 
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test Android Banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Test iOS Banner
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
