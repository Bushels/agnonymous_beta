import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../main.dart'; // To access supabase client

final presenceProvider = NotifierProvider<PresenceNotifier, int>(PresenceNotifier.new);

class PresenceNotifier extends Notifier<int> with WidgetsBindingObserver {
  RealtimeChannel? _channel;
  final String _presenceKey = const Uuid().v4(); // Stable key for this session

  @override
  int build() {
    // Start real-time tracking
    _initializePresence();
    
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Clean up on dispose
    ref.onDispose(() async {
      WidgetsBinding.instance.removeObserver(this);
      await _cleanup();
    });
    
    return 1; // Start with at least 1 (me)
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached) {
      // App going to background or closing - untrack presence
      _channel?.untrack();
      logger.d('👥 Presence: App backgrounded, untracked');
    } else if (state == AppLifecycleState.resumed) {
      // App coming back to foreground - re-track presence
      _trackPresence();
      logger.d('👥 Presence: App resumed, re-tracked');
    }
  }

  int _countOnlineUsers() {
    final presenceState = _channel?.presenceState();
    if (presenceState == null || presenceState.isEmpty) return 1;
    
    // presenceState is List<SinglePresenceState> where each entry has 'presences' list
    // Count all presences across all entries
    int count = 0;
    for (final entry in presenceState) {
      count += entry.presences.length;
    }
    
    return count > 0 ? count : 1;
  }

  Future<void> _trackPresence() async {
    try {
      await _channel?.track({
        'presence_key': _presenceKey,
        'online_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      logger.w('👥 Presence: Failed to track', error: e);
    }
  }

  Future<void> _cleanup() async {
    try {
      await _channel?.untrack();
      await _channel?.unsubscribe();
      _channel = null;
    } catch (e) {
      logger.w('👥 Presence: Cleanup error', error: e);
    }
  }

  Future<void> _initializePresence() async {
    try {
      // Use a dedicated presence channel with proper config
      _channel = supabase.channel(
        'presence:online_users',
        opts: RealtimeChannelConfig(
          key: _presenceKey, // Use our stable key
        ),
      );

      // Listen to all presence events for accurate counting
      _channel?.onPresenceSync((payload) {
        state = _countOnlineUsers();
        logger.d('👥 Presence sync: $state active users');
      });

      _channel?.onPresenceJoin((payload) {
        state = _countOnlineUsers();
        logger.d('👥 Presence join: $state active users');
      });

      _channel?.onPresenceLeave((payload) {
        state = _countOnlineUsers();
        logger.d('👥 Presence leave: $state active users');
      });

      // Subscribe and then track our presence
      _channel?.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _trackPresence();
          logger.i('👥 Presence: Connected and tracked');
        } else if (status == RealtimeSubscribeStatus.closed) {
          logger.w('👥 Presence: Channel closed');
        } else if (error != null) {
          logger.e('👥 Presence: Subscription error', error: error);
        }
      });
      
    } catch (e) {
      logger.e('👥 Presence: Initialization error', error: e);
      // Keep state at 1 (just me) on error
    }
  }
}
