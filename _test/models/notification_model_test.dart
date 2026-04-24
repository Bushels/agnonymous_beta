import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/notification_model.dart';

void main() {
  group('NotificationType', () {
    test('displayName returns correct values', () {
      expect(NotificationType.vote.displayName, 'Vote');
      expect(NotificationType.comment.displayName, 'Comment');
      expect(NotificationType.mention.displayName, 'Mention');
      expect(NotificationType.priceAlert.displayName, 'Price Alert');
      expect(NotificationType.system.displayName, 'System');
    });

    group('fromString', () {
      test('parses vote correctly', () {
        expect(NotificationType.fromString('vote'), NotificationType.vote);
      });

      test('parses comment correctly', () {
        expect(NotificationType.fromString('comment'), NotificationType.comment);
      });

      test('parses mention correctly', () {
        expect(NotificationType.fromString('mention'), NotificationType.mention);
      });

      test('parses price_alert correctly', () {
        expect(NotificationType.fromString('price_alert'), NotificationType.priceAlert);
      });

      test('parses system correctly', () {
        expect(NotificationType.fromString('system'), NotificationType.system);
      });

      test('returns system for unknown type', () {
        expect(NotificationType.fromString('unknown'), NotificationType.system);
        expect(NotificationType.fromString('invalid'), NotificationType.system);
        expect(NotificationType.fromString(''), NotificationType.system);
      });
    });
  });

  group('UserNotification', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    test('creates instance with required fields', () {
      final notification = UserNotification(
        id: 'notif-123',
        userId: 'user-123',
        type: NotificationType.vote,
        title: 'New Vote',
        message: 'Someone voted on your post',
        createdAt: testDate,
      );

      expect(notification.id, 'notif-123');
      expect(notification.userId, 'user-123');
      expect(notification.type, NotificationType.vote);
      expect(notification.title, 'New Vote');
      expect(notification.message, 'Someone voted on your post');
      expect(notification.isRead, false); // default
      expect(notification.actorIsAnonymous, true); // default
    });

    test('creates instance with all fields', () {
      final readAt = DateTime(2024, 1, 15, 11, 0);
      final notification = UserNotification(
        id: 'notif-456',
        userId: 'user-456',
        type: NotificationType.comment,
        title: 'New Comment',
        message: 'John commented on your post',
        postId: 'post-123',
        commentId: 'comment-456',
        voteType: null,
        actorId: 'actor-789',
        actorUsername: 'John',
        actorIsAnonymous: false,
        isRead: true,
        readAt: readAt,
        createdAt: testDate,
      );

      expect(notification.postId, 'post-123');
      expect(notification.commentId, 'comment-456');
      expect(notification.actorUsername, 'John');
      expect(notification.actorIsAnonymous, false);
      expect(notification.isRead, true);
      expect(notification.readAt, readAt);
    });

    group('fromMap', () {
      test('parses valid map correctly', () {
        final map = {
          'id': 'notif-map',
          'user_id': 'user-map',
          'type': 'vote',
          'title': 'Vote Received',
          'message': 'You got a thumbs up!',
          'post_id': 'post-1',
          'vote_type': 'thumbs_up',
          'actor_id': 'actor-1',
          'actor_username': 'Farmer123',
          'actor_is_anonymous': false,
          'is_read': false,
          'created_at': '2024-01-15T10:30:00.000',
        };

        final notification = UserNotification.fromMap(map);

        expect(notification.id, 'notif-map');
        expect(notification.type, NotificationType.vote);
        expect(notification.title, 'Vote Received');
        expect(notification.postId, 'post-1');
        expect(notification.voteType, 'thumbs_up');
        expect(notification.actorUsername, 'Farmer123');
        expect(notification.actorIsAnonymous, false);
      });

      test('handles null optional fields', () {
        final map = {
          'id': 'notif-minimal',
          'user_id': 'user-1',
          'type': 'system',
          'title': 'System Update',
          'message': 'New features available',
          'created_at': '2024-01-15T10:30:00.000',
        };

        final notification = UserNotification.fromMap(map);

        expect(notification.postId, isNull);
        expect(notification.commentId, isNull);
        expect(notification.voteType, isNull);
        expect(notification.actorId, isNull);
        expect(notification.actorUsername, isNull);
        expect(notification.actorIsAnonymous, true);
        expect(notification.isRead, false);
        expect(notification.readAt, isNull);
      });

      test('parses read notification with readAt', () {
        final map = {
          'id': 'notif-read',
          'user_id': 'user-1',
          'type': 'comment',
          'title': 'Comment',
          'message': 'New comment',
          'is_read': true,
          'read_at': '2024-01-15T11:00:00.000',
          'created_at': '2024-01-15T10:30:00.000',
        };

        final notification = UserNotification.fromMap(map);

        expect(notification.isRead, true);
        expect(notification.readAt, isNotNull);
        expect(notification.readAt!.hour, 11);
      });
    });

    group('copyWith', () {
      test('creates copy with updated isRead', () {
        final original = UserNotification(
          id: 'notif-copy',
          userId: 'user-1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'New vote',
          isRead: false,
          createdAt: testDate,
        );

        final copy = original.copyWith(isRead: true);

        expect(copy.id, original.id);
        expect(copy.title, original.title);
        expect(copy.isRead, true);
      });

      test('creates copy with updated readAt', () {
        final readTime = DateTime(2024, 1, 15, 12, 0);
        final original = UserNotification(
          id: 'notif-copy2',
          userId: 'user-1',
          type: NotificationType.comment,
          title: 'Comment',
          message: 'New comment',
          createdAt: testDate,
        );

        final copy = original.copyWith(isRead: true, readAt: readTime);

        expect(copy.isRead, true);
        expect(copy.readAt, readTime);
      });

      test('preserves original when no changes', () {
        final original = UserNotification(
          id: 'notif-preserve',
          userId: 'user-1',
          type: NotificationType.mention,
          title: 'Mention',
          message: 'You were mentioned',
          isRead: true,
          createdAt: testDate,
        );

        final copy = original.copyWith();

        expect(copy.isRead, original.isRead);
        expect(copy.readAt, original.readAt);
      });
    });

    group('icon', () {
      test('returns correct icon for thumbs_up vote', () {
        final notification = UserNotification(
          id: 'n1',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          voteType: 'thumbs_up',
          createdAt: testDate,
        );

        expect(notification.icon, '👍');
      });

      test('returns correct icon for thumbs_down vote', () {
        final notification = UserNotification(
          id: 'n2',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          voteType: 'thumbs_down',
          createdAt: testDate,
        );

        expect(notification.icon, '👎');
      });

      test('returns correct icon for partial vote', () {
        final notification = UserNotification(
          id: 'n3',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          voteType: 'partial',
          createdAt: testDate,
        );

        expect(notification.icon, '🤔');
      });

      test('returns correct icon for funny vote', () {
        final notification = UserNotification(
          id: 'n4',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          voteType: 'funny',
          createdAt: testDate,
        );

        expect(notification.icon, '😂');
      });

      test('returns default icon for unknown vote type', () {
        final notification = UserNotification(
          id: 'n5',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          voteType: 'unknown',
          createdAt: testDate,
        );

        expect(notification.icon, '✓');
      });

      test('returns correct icon for comment', () {
        final notification = UserNotification(
          id: 'n6',
          userId: 'u1',
          type: NotificationType.comment,
          title: 'Comment',
          message: 'Message',
          createdAt: testDate,
        );

        expect(notification.icon, '💬');
      });

      test('returns correct icon for mention', () {
        final notification = UserNotification(
          id: 'n7',
          userId: 'u1',
          type: NotificationType.mention,
          title: 'Mention',
          message: 'Message',
          createdAt: testDate,
        );

        expect(notification.icon, '@');
      });

      test('returns correct icon for priceAlert', () {
        final notification = UserNotification(
          id: 'n8',
          userId: 'u1',
          type: NotificationType.priceAlert,
          title: 'Alert',
          message: 'Message',
          createdAt: testDate,
        );

        expect(notification.icon, '💰');
      });

      test('returns correct icon for system', () {
        final notification = UserNotification(
          id: 'n9',
          userId: 'u1',
          type: NotificationType.system,
          title: 'System',
          message: 'Message',
          createdAt: testDate,
        );

        expect(notification.icon, '🔔');
      });
    });

    group('timeAgo', () {
      test('returns "Just now" for recent notification', () {
        final notification = UserNotification(
          id: 'time-1',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
        );

        expect(notification.timeAgo, 'Just now');
      });

      test('returns minutes ago', () {
        final notification = UserNotification(
          id: 'time-2',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        expect(notification.timeAgo, '5m ago');
      });

      test('returns hours ago', () {
        final notification = UserNotification(
          id: 'time-3',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        );

        expect(notification.timeAgo, '3h ago');
      });

      test('returns days ago', () {
        final notification = UserNotification(
          id: 'time-4',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        );

        expect(notification.timeAgo, '5d ago');
      });

      test('returns weeks ago for 7+ days', () {
        final notification = UserNotification(
          id: 'time-5',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          createdAt: DateTime.now().subtract(const Duration(days: 14)),
        );

        expect(notification.timeAgo, '2w ago');
      });

      test('returns 1 week ago for 7-13 days', () {
        final notification = UserNotification(
          id: 'time-6',
          userId: 'u1',
          type: NotificationType.vote,
          title: 'Vote',
          message: 'Message',
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        );

        expect(notification.timeAgo, '1w ago');
      });
    });
  });
}
