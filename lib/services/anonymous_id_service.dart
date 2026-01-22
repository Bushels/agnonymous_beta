import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AnonymousIdService {
  static const String _storageKey = 'anonymous_device_id';
  static String? _cachedId;

  /// Get the persistent anonymous ID for this device
  static Future<String> getAnonymousId() async {
    if (_cachedId != null) return _cachedId!;

    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_storageKey);

    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_storageKey, id);
    }

    _cachedId = id;
    return id;
  }

  /// Get the headers required for anonymous RLS policies
  static Future<Map<String, String>> getHeaders() async {
    final id = await getAnonymousId();
    return {
      'x-anonymous-id': id,
    };
  }
  
  /// Get current cached ID synchronously if initialized, otherwise returns null
  /// useful for synchronous UI updates where Future is not ideal
  static String? get currentId => _cachedId;
}
