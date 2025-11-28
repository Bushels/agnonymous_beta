/// Models for the notification system

/// Notification type enum
enum NotificationType {
  vote,
  comment,
  mention,
  priceAlert,
  system;

  String get displayName {
    switch (this) {
      case NotificationType.vote:
        return 'Vote';
      case NotificationType.comment:
        return 'Comment';
      case NotificationType.mention:
        return 'Mention';
      case NotificationType.priceAlert:
        return 'Price Alert';
      case NotificationType.system:
        return 'System';
    }
  }

  static NotificationType fromString(String value) {
    switch (value) {
      case 'vote':
        return NotificationType.vote;
      case 'comment':
        return NotificationType.comment;
      case 'mention':
        return NotificationType.mention;
      case 'price_alert':
        return NotificationType.priceAlert;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }
}

/// User notification model
class UserNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;

  // Related entities
  final String? postId;
  final String? commentId;
  final String? voteType;

  // Actor info
  final String? actorId;
  final String? actorUsername;
  final bool actorIsAnonymous;

  // Status
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const UserNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.postId,
    this.commentId,
    this.voteType,
    this.actorId,
    this.actorUsername,
    this.actorIsAnonymous = true,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory UserNotification.fromMap(Map<String, dynamic> map) {
    return UserNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: NotificationType.fromString(map['type'] as String),
      title: map['title'] as String,
      message: map['message'] as String,
      postId: map['post_id'] as String?,
      commentId: map['comment_id'] as String?,
      voteType: map['vote_type'] as String?,
      actorId: map['actor_id'] as String?,
      actorUsername: map['actor_username'] as String?,
      actorIsAnonymous: map['actor_is_anonymous'] as bool? ?? true,
      isRead: map['is_read'] as bool? ?? false,
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  UserNotification copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return UserNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      postId: postId,
      commentId: commentId,
      voteType: voteType,
      actorId: actorId,
      actorUsername: actorUsername,
      actorIsAnonymous: actorIsAnonymous,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  /// Get the icon for this notification type
  String get icon {
    switch (type) {
      case NotificationType.vote:
        switch (voteType) {
          case 'thumbs_up':
            return '👍';
          case 'thumbs_down':
            return '👎';
          case 'partial':
            return '🤔';
          case 'funny':
            return '😂';
          default:
            return '✓';
        }
      case NotificationType.comment:
        return '💬';
      case NotificationType.mention:
        return '@';
      case NotificationType.priceAlert:
        return '💰';
      case NotificationType.system:
        return '🔔';
    }
  }

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
