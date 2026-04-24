import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Rotate the anonymous device ID.
  ///
  /// Generates a fresh UUID, overwrites the stored value, clears the in-memory
  /// cache, and pushes the new value into the already-initialized Supabase
  /// client so subsequent RPCs send the new `x-anonymous-id` header.
  /// Caller is responsible for wiping any local state keyed to the old id
  /// (e.g. watched threads).
  static Future<String> resetAnonymousId() async {
    final newId = const Uuid().v4();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, newId);
    _cachedId = newId;

    // Update the live Supabase client header. SupabaseClient.headers is a
    // mutable map captured at initialize(); mutating it takes effect on
    // subsequent REST/RPC calls without a re-init.
    try {
      Supabase.instance.client.headers['x-anonymous-id'] = newId;
    } catch (_) {
      // Supabase not initialized yet — nothing to update.
    }
    return newId;
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
