import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../main.dart' show supabase, logger;

// ============================================
// NOTIFICATIONS STATE
// ============================================

/// State for user notifications
class NotificationsState {
  final List<UserNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<UserNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ============================================
// NOTIFICATIONS NOTIFIER
// ============================================

/// Notifications notifier with real-time updates
class NotificationsNotifier extends Notifier<NotificationsState> {
  RealtimeChannel? _notificationsChannel;

  @override
  NotificationsState build() {
    // Setup real-time subscription
    _initRealTime();

    // Defer loading to next microtask to avoid circular dependency
    Future.microtask(() => loadNotifications());

    // Cleanup on dispose
    ref.onDispose(() {
      _notificationsChannel?.unsubscribe();
    });

    return const NotificationsState(isLoading: true);
  }

  void _initRealTime() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notificationsChannel = supabase
        .channel('user_notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            logger.d('New notification received');
            final newNotification =
                UserNotification.fromMap(payload.newRecord);
            state = state.copyWith(
              notifications: [newNotification, ...state.notifications],
              unreadCount: state.unreadCount + 1,
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            logger.d('Notification updated');
            final updatedNotification =
                UserNotification.fromMap(payload.newRecord);
            final updatedList = state.notifications.map((n) {
              return n.id == updatedNotification.id ? updatedNotification : n;
            }).toList();

            // Recalculate unread count
            final unreadCount =
                updatedList.where((n) => !n.isRead).length;

            state = state.copyWith(
              notifications: updatedList,
              unreadCount: unreadCount,
            );
          },
        )
        .subscribe();
  }

  /// Load notifications for current user
  Future<void> loadNotifications({int limit = 50}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      state = const NotificationsState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch notifications
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final notifications = (response as List<dynamic>)
          .map((e) => UserNotification.fromMap(e as Map<String, dynamic>))
          .toList();

      // Get unread count
      final unreadCount = notifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      logger.e('Error loading notifications: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications',
      );
    }
  }

  /// Mark specific notifications as read
  Future<void> markAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;

    try {
      await supabase.rpc('mark_notifications_read', params: {
        'notification_ids': notificationIds,
      });

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        if (notificationIds.contains(n.id)) {
          return n.copyWith(isRead: true, readAt: DateTime.now());
        }
        return n;
      }).toList();

      final unreadCount =
          updatedNotifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      logger.e('Error marking notifications as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await supabase.rpc('mark_all_notifications_read');

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        return n.copyWith(isRead: true, readAt: DateTime.now());
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );
    } catch (e) {
      logger.e('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      final updatedNotifications =
          state.notifications.where((n) => n.id != notificationId).toList();

      final unreadCount =
          updatedNotifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      logger.e('Error deleting notification: $e');
    }
  }

  /// Refresh notifications
  Future<void> refresh() => loadNotifications();
}

// ============================================
// PROVIDERS
// ============================================

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);

/// Provider for just the unread count (for badges)
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});

/// Provider for activity notifications only (votes + comments)
final activityNotificationsProvider = Provider<List<UserNotification>>((ref) {
  final notifications = ref.watch(notificationsProvider).notifications;
  return notifications
      .where((n) =>
          n.type == NotificationType.vote ||
          n.type == NotificationType.comment ||
          n.type == NotificationType.mention)
      .toList();
});
