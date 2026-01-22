import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:js_interop';

/// Service for playing UI sounds with user preference support
class SoundService {
  static const String _soundEnabledKey = 'sound_effects_enabled';
  static bool _soundEnabled = true;
  static bool _initialized = false;

  /// Initialize the sound service and load user preferences
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      _initialized = true;
    } catch (e) {
      debugPrint('SoundService: Failed to load preferences: $e');
      _soundEnabled = true;
    }
  }

  /// Check if sound effects are enabled
  static bool get isSoundEnabled => _soundEnabled;

  /// Enable or disable sound effects
  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, enabled);
    } catch (e) {
      debugPrint('SoundService: Failed to save preference: $e');
    }
  }

  /// Toggle sound effects on/off
  static Future<void> toggleSound() async {
    await setSoundEnabled(!_soundEnabled);
  }

  /// Play a subtle pop sound for the funny button
  static void playFunnyPop() {
    if (!_soundEnabled) return;
    
    if (kIsWeb) {
      _playWebSound();
    }
    // For native platforms, we could add platform-specific audio here
  }

  /// Play sound using Web Audio API via JavaScript interop
  static void _playWebSound() {
    if (!kIsWeb) return;
    
    try {
      // JavaScript code to play a synthesized pop sound using Web Audio API
      const jsCode = '''
        (function() {
          try {
            const ctx = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = ctx.createOscillator();
            const gainNode = ctx.createGain();
            
            oscillator.connect(gainNode);
            gainNode.connect(ctx.destination);
            
            // Pop sound: quick frequency sweep with fast decay
            oscillator.frequency.setValueAtTime(600, ctx.currentTime);
            oscillator.frequency.exponentialRampToValueAtTime(200, ctx.currentTime + 0.1);
            
            gainNode.gain.setValueAtTime(0.15, ctx.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.1);
            
            oscillator.type = 'sine';
            oscillator.start(ctx.currentTime);
            oscillator.stop(ctx.currentTime + 0.1);
          } catch(e) { /* Silent fail */ }
        })();
      ''';
      
      _evalJs(jsCode.toJS);
    } catch (e) {
      debugPrint('SoundService: Failed to play sound: $e');
    }
  }
}

/// JavaScript eval function for running audio code
@JS('eval')
external void _evalJs(JSString code);
