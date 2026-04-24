import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AnonymousIdService {
  static const String _storageKey = 'anonymous_device_id';
  static const String _displayNameKey = 'anonymous_display_name';
  static const String defaultDisplayName = 'Anonymous Farmer';
  static String? _cachedId;
  static String? _cachedDisplayName;

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

  /// Optional public display label saved on this device.
  ///
  /// This is not an account and should never be treated as proof of identity.
  /// It only saves the farmer from retyping a preferred anonymous handle.
  static Future<String?> getSavedDisplayName() async {
    if (_cachedDisplayName != null) return _cachedDisplayName;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_displayNameKey);
    final normalized = normalizeDisplayName(stored ?? '');
    _cachedDisplayName = normalized.isEmpty ? null : normalized;
    return _cachedDisplayName;
  }

  static Future<String> getDisplayNameLabel() async {
    return await getSavedDisplayName() ?? defaultDisplayName;
  }

  static Future<void> setSavedDisplayName(String? displayName) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = normalizeDisplayName(displayName ?? '');

    if (normalized.isEmpty) {
      await prefs.remove(_displayNameKey);
      _cachedDisplayName = null;
      return;
    }

    await prefs.setString(_displayNameKey, normalized);
    _cachedDisplayName = normalized;
  }

  static String normalizeDisplayName(String value) {
    final collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return '';
    final visibleOnly = collapsed.replaceAll(RegExp(r'[<>]'), '');
    if (visibleOnly.length <= 24) return visibleOnly;
    return visibleOnly.substring(0, 24).trim();
  }

  /// Get current cached ID synchronously if initialized, otherwise returns null
  /// useful for synchronous UI updates where Future is not ideal
  static String? get currentId => _cachedId;

  static String? get currentDisplayName => _cachedDisplayName;
}
