import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/core/models/comment.dart';

void main() {
  group('Comment', () {
    group('fromMap()', () {
      test('constructs correctly from a full map', () {
        final map = {
          'id': 'comment-789',
          'content': 'Great insight on canola futures.',
          'created_at': '2026-03-01T15:30:00Z',
          'user_id': 'user-456',
          'is_anonymous': false,
          'author_username': 'GrainTrader',
          'author_verified': true,
          'is_deleted': false,
          'deleted_at': null,
          'edited_at': '2026-03-01T16:00:00Z',
        };

        final comment = Comment.fromMap(map);

        expect(comment.id, 'comment-789');
        expect(comment.content, 'Great insight on canola futures.');
        expect(comment.createdAt, DateTime.parse('2026-03-01T15:30:00Z'));
        expect(comment.userId, 'user-456');
        expect(comment.isAnonymous, false);
        expect(comment.authorUsername, 'GrainTrader');
        expect(comment.authorVerified, true);
        expect(comment.isDeleted, false);
        expect(comment.deletedAt, isNull);
        expect(comment.editedAt, DateTime.parse('2026-03-01T16:00:00Z'));
      });

      test('handles missing optional fields with defaults', () {
        final map = {
          'id': 'comment-minimal',
          'content': 'Short comment.',
          'created_at': '2026-02-15T10:00:00Z',
        };

        final comment = Comment.fromMap(map);

        expect(comment.id, 'comment-minimal');
        expect(comment.content, 'Short comment.');
        expect(comment.createdAt, DateTime.parse('2026-02-15T10:00:00Z'));
        expect(comment.userId, isNull);
        expect(comment.isAnonymous, true);
        expect(comment.authorUsername, isNull);
        expect(comment.authorVerified, false);
        expect(comment.isDeleted, false);
        expect(comment.deletedAt, isNull);
        expect(comment.editedAt, isNull);
      });

      test('parses deleted_at when provided', () {
        final comment = Comment.fromMap({
          'id': 'comment-del',
          'content': 'Deleted comment.',
          'created_at': '2026-01-01T00:00:00Z',
          'is_deleted': true,
          'deleted_at': '2026-01-02T12:00:00Z',
        });

        expect(comment.isDeleted, true);
        expect(comment.deletedAt, DateTime.parse('2026-01-02T12:00:00Z'));
      });
    });

    group('authorDisplay', () {
      test('returns "Anonymous" when isAnonymous is true', () {
        final comment = Comment.fromMap({
          'id': 'c1',
          'content': 'test',
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': true,
          'author_username': 'ShouldNotShow',
        });
        expect(comment.authorDisplay, 'Anonymous');
      });

      test('returns username when not anonymous and username is set', () {
        final comment = Comment.fromMap({
          'id': 'c2',
          'content': 'test',
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': false,
          'author_username': 'WheatKing',
        });
        expect(comment.authorDisplay, 'WheatKing');
      });

      test('returns "Unknown User" when not anonymous and username is null',
          () {
        final comment = Comment.fromMap({
          'id': 'c3',
          'content': 'test',
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': false,
          'author_username': null,
        });
        expect(comment.authorDisplay, 'Unknown User');
      });
    });

    group('authorBadge', () {
      test('returns mask emoji when anonymous', () {
        final comment = Comment.fromMap({
          'id': 'c1',
          'content': 'test',
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': true,
        });
        expect(comment.authorBadge, '\u{1F3AD}');
      });

      test('returns checkmark emoji when not anonymous and verified', () {
        final comment = Comment.fromMap({
          'id': 'c2',
          'content': 'test',
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': false,
          'author_verified': true,
        });
        expect(comment.authorBadge, '\u2705');
      });

      test('returns warning emoji when not anonymous and not verified', () {
        final comment = Comment.fromMap({
          'id': 'c3',
          'content': 'test',
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': false,
          'author_verified': false,
        });
        expect(comment.authorBadge, '\u26A0\uFE0F');
      });
    });

    group('wasEdited', () {
      test('returns true when editedAt is non-null', () {
        final comment = Comment.fromMap({
          'id': 'c1',
          'content': 'edited comment',
          'created_at': '2026-01-01T00:00:00Z',
          'edited_at': '2026-01-01T01:00:00Z',
        });
        expect(comment.wasEdited, true);
      });

      test('returns false when editedAt is null', () {
        final comment = Comment.fromMap({
          'id': 'c2',
          'content': 'original comment',
          'created_at': '2026-01-01T00:00:00Z',
          'edited_at': null,
        });
        expect(comment.wasEdited, false);
      });

      test('returns false when editedAt is not provided', () {
        final comment = Comment.fromMap({
          'id': 'c3',
          'content': 'another comment',
          'created_at': '2026-01-01T00:00:00Z',
        });
        expect(comment.wasEdited, false);
      });
    });
  });
}
