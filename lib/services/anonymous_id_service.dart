import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class AnonymousIdService {
  static const String _storageKey = 'anonymous_device_id';
  static const String _displayNameKey = 'anonymous_display_name';
  static const String defaultDisplayName = 'Anonymous Farmer';
  static String? _cachedId;
  static String? _cachedDisplayName;
  static String? authInitError;

  /// Get the persistent anonymous ID for this device (Firebase Auth UID)
  static Future<String> getAnonymousId() async {
    if (_cachedId != null) return _cachedId!;

    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) {
      _cachedId = auth.currentUser!.uid;
      return _cachedId!;
    }

    // Fallback: If auth isn't fully ready yet, try to sign in
    try {
      final userCredential = await auth.signInAnonymously();
      _cachedId = userCredential.user?.uid;
      if (_cachedId != null) return _cachedId!;
    } catch (e) {
      authInitError = e.toString();
    }

    // Ultimate fallback using UUID
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
  /// Signs out of the current anonymous user and signs in as a new one to generate a fresh UID.
  static Future<String> resetAnonymousId() async {
    final auth = FirebaseAuth.instance;
    try {
      await auth.signOut();
      final credential = await auth.signInAnonymously();
      _cachedId = credential.user?.uid;
    } catch (e) {
      authInitError = e.toString();
      _cachedId = null;
    }

    if (_cachedId == null) {
      final newId = const Uuid().v4();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, newId);
      _cachedId = newId;
    }
    return _cachedId!;
  }

  /// Get headers for backward compatibility
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

  /// Clear in-memory identity cache (called on auth state changes)
  static void clearCache() {
    _cachedId = null;
    _cachedDisplayName = null;
  }
}
